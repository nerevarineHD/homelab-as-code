# Additive: CT111 and all existing resources remain unchanged.
# Enabled by default since VM 114 was created (Nov 8, 2026).
variable "codex_vm_enabled" {
  type        = bool
  description = "Manage the Codex VM (VM 114) and its firewall. It exists since Nov 8, 2026; false would plan its destruction (prevent_destroy blocks that)."
  default     = true
}

variable "codex_image_url" {
  type        = string
  description = "Dated official Debian 13 genericcloud amd64 qcow2 URL; never latest."
  default     = "https://cloud.debian.org/images/cloud/trixie/20261103-2651/debian-13-genericcloud-amd64-20261103-2651.qcow2"
  validation {
    condition     = var.codex_image_url == "" || can(regex("^https://cloud[.]debian[.]org/images/cloud/trixie/[0-9]+-[0-9]+/debian-13-genericcloud-amd64-[0-9]+-[0-9]+[.]qcow2$", var.codex_image_url))
    error_message = "Use a dated official Debian 13 genericcloud amd64 image URL."
  }
}

variable "codex_image_sha512" {
  type        = string
  description = "SHA-512 retrieved from the official dated Debian manifest over HTTPS."
  default     = "d25999de0770d4cde1be72c299ba3ad94eac7ea8fd4d18f8cc86c69df69337e2e8a91d64465a9bfd8f2a78c566fcbcb0842eacc91c09efdef72d719d9f13b535"
  validation {
    condition     = var.codex_image_sha512 == "" || can(regex("^[a-f0-9]{128}$", var.codex_image_sha512))
    error_message = "Provide a lowercase 128-character SHA-512 digest."
  }
}

resource "proxmox_download_file" "codex_image" {
  count              = var.codex_vm_enabled ? 1 : 0
  node_name          = "pve"
  datastore_id       = "local"
  content_type       = "import"
  file_name          = "codex-debian-13.qcow2"
  url                = var.codex_image_url
  checksum           = var.codex_image_sha512
  checksum_algorithm = "sha512"
  overwrite          = false
  lifecycle {
    precondition {
      condition     = var.codex_image_url != "" && var.codex_image_sha512 != ""
      error_message = "Review and supply the dated Debian image URL and verified SHA-512 before enabling."
    }
  }
}

resource "proxmox_virtual_environment_vm" "codex" {
  count       = var.codex_vm_enabled ? 1 : 0
  node_name   = "pve"
  vm_id       = 114
  name        = "codex"
  description = "Isolated Codex VM. Managed by OpenTofu."
  tags        = ["codex", "tofu"]

  # First boot is manual, AFTER firewall verification. No unfiltered boot window.
  started         = false
  on_boot         = false
  stop_on_destroy = true
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"
  tablet_device   = false
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [started, disk[0].import_from]
  }
  agent {
    enabled = false # enable only after Ansible installs and verifies qemu-guest-agent
  }
  cpu {
    cores = 2
    type  = "host"
  }
  memory {
    dedicated = 4096
  }
  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    import_from  = proxmox_download_file.codex_image[0].id
    size         = 32
    discard      = "on"
    ssd          = true
    iothread     = true
  }
  boot_order = ["scsi0"]
  operating_system {
    type = "l26"
  }
  initialization {
    datastore_id = "local-zfs"
    upgrade      = false
    dns {
      servers = ["1.1.1.1"]
    }
    ip_config {
      ipv4 {
        address = "192.168.0.27/24"
        gateway = "192.168.0.1"
      }
    }
    user_account {
      username = "root"
      keys     = [local.ansible_ssh_key]
    }
  }
  network_device {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = true
  }
  serial_device {}
}

resource "proxmox_virtual_environment_firewall_ipset" "codex_ipfilter" {
  count     = var.codex_vm_enabled ? 1 : 0
  node_name = "pve"
  vm_id     = proxmox_virtual_environment_vm.codex[0].vm_id
  name      = "ipfilter-net0"
  cidr {
    # No /32: Proxmox stores a single host without it, and any cidr difference forces a replace.
    name = "192.168.0.27"
  }
}

resource "proxmox_virtual_environment_firewall_options" "codex" {
  count = var.codex_vm_enabled ? 1 : 0
  depends_on = [
    proxmox_virtual_environment_cluster_firewall.datacenter,
    proxmox_virtual_environment_firewall_ipset.codex_ipfilter,
  ]
  node_name     = "pve"
  vm_id         = proxmox_virtual_environment_vm.codex[0].vm_id
  enabled       = true
  input_policy  = "DROP"
  output_policy = "DROP"
  ipfilter      = true
  macfilter     = true
  dhcp          = false
  ndp           = false
  radv          = false
}

resource "proxmox_virtual_environment_firewall_rules" "codex" {
  count      = var.codex_vm_enabled ? 1 : 0
  depends_on = [proxmox_virtual_environment_firewall_options.codex]
  node_name  = "pve"
  vm_id      = proxmox_virtual_environment_vm.codex[0].vm_id
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Administrator SSH from pve only"
    source  = "192.168.0.10"
    proto   = "tcp"
    dport   = "22"
  }
  rule {
    type    = "out"
    action  = "DROP"
    comment = "No IPv6 egress"
    dest    = "::/0"
  }
  rule {
    type    = "out"
    action  = "DROP"
    comment = "No private, local, multicast or reserved IPv4 destinations"
    dest    = "0.0.0.0/8,10.0.0.0/8,100.64.0.0/10,127.0.0.0/8,169.254.0.0/16,172.16.0.0/12,192.168.0.0/16,224.0.0.0/4,240.0.0.0/4"
    log     = "info"
  }
  rule {
    type   = "out"
    action = "ACCEPT"
    dest   = "1.1.1.1"
    proto  = "udp"
    dport  = "53"
  }
  rule {
    type   = "out"
    action = "ACCEPT"
    dest   = "1.1.1.1"
    proto  = "tcp"
    dport  = "53"
  }
  rule {
    type    = "out"
    action  = "ACCEPT"
    comment = "Public HTTP and HTTPS for Debian packages and Codex"
    proto   = "tcp"
    dport   = "80,443"
  }
  rule {
    type    = "out"
    action  = "ACCEPT"
    comment = "Public NTP for correct TLS time"
    proto   = "udp"
    dport   = "123"
  }
}


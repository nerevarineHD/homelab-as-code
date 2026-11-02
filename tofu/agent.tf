# CT 111 - agent: Claude Code harness sandbox (learning project, phase 1 = read-only).
# The container is the wall: unprivileged, no nesting, a non-root user, and a Proxmox firewall
# that lets it reach the internet but nothing on the private ranges. Only pve may SSH in.
resource "proxmox_virtual_environment_container" "agent" {
  lifecycle {
    ignore_changes = [operating_system[0].template_file_id, initialization[0].user_account]
  }

  node_name     = "pve"
  vm_id         = 111
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
    swap      = 512
  }

  disk {
    datastore_id = "local-zfs"
    size         = 16
  }

  # No nesting/keyctl: nothing in here needs Docker or nested namespaces.

  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }

  initialization {
    hostname = "agent"

    dns {
      servers = ["1.1.1.1"] # public resolver: the firewall below blocks Pi-hole like any other LAN host
    }

    ip_config {
      ipv4 {
        address = "192.168.0.24/24"
        gateway = "192.168.0.1"
      }
    }

    user_account {
      keys = [local.ansible_ssh_key]
    }
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = true # required for the rules below to apply
  }

  startup {
    order    = 9
    up_delay = 5
  }
}

# Datacenter firewall switch. Proxmox ignores every VM/CT firewall until this is on.
# ACCEPT policies keep the host and every other CT exactly as open as before; only CTs whose own
# firewall options are enabled (just CT 111 for now) get filtered.
resource "proxmox_virtual_environment_cluster_firewall" "datacenter" {
  enabled        = true
  ebtables       = true
  input_policy   = "ACCEPT"
  output_policy  = "ACCEPT"
  forward_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_options" "agent" {
  depends_on = [proxmox_virtual_environment_cluster_firewall.datacenter]

  node_name    = proxmox_virtual_environment_container.agent.node_name
  container_id = proxmox_virtual_environment_container.agent.vm_id

  enabled       = true
  input_policy  = "DROP"   # nothing gets in except the rules below
  output_policy = "ACCEPT" # the internet is fine; the private ranges are dropped by rule
  ipfilter      = true     # it can't change its own IP to dodge the rules
  macfilter     = true
  dhcp          = false
  ndp           = false
  radv          = false
  log_level_in  = "nolog"
  log_level_out = "nolog"
}

# First match wins. Dropped attempts are logged to /var/log/pve-firewall.log on pve.
resource "proxmox_virtual_environment_firewall_rules" "agent" {
  depends_on = [proxmox_virtual_environment_firewall_options.agent]

  node_name    = proxmox_virtual_environment_container.agent.node_name
  container_id = proxmox_virtual_environment_container.agent.vm_id

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Ansible from pve"
    source  = "192.168.0.10"
    proto   = "tcp"
    dport   = "22"
  }

  # Phase 2 (drift checks) adds one OUT ACCEPT to 192.168.0.10:22 here, above the drops.

  rule {
    type    = "out"
    action  = "DROP"
    comment = "No home networks (LAN, IoT, DMZ, pve, router, every CT)"
    dest    = "192.168.0.0/16"
    log     = "info"
  }

  rule {
    type    = "out"
    action  = "DROP"
    comment = "No other private, CGNAT or link-local ranges"
    dest    = "10.0.0.0/8,172.16.0.0/12,100.64.0.0/10,169.254.0.0/16"
    log     = "info"
  }
}

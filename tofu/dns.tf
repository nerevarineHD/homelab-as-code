# CT 105 - Pi-hole + Unbound (local DNS + ad blocking)
resource "proxmox_virtual_environment_container" "dns" {
  lifecycle {
    ignore_changes = [operating_system[0].template_file_id, initialization[0].user_account]
  }

  node_name     = "pve"
  vm_id         = 105
  unprivileged  = true # no bind mounts or Docker needed
  start_on_boot = true
  started       = true

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
    swap      = 256
  }

  disk {
    datastore_id = "local-zfs"
    size         = 8
  }

  features {
    nesting = true # lets systemd work properly inside an unprivileged Debian 13 container
  }

  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }

  initialization {
    hostname = "dns"

    dns {
      servers = ["1.1.1.1"] # the container's own lookups; never itself, to avoid a loop
    }

    ip_config {
      ipv4 {
        address = "192.168.0.20/24"
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
    firewall = true
  }

  startup {
    order    = 1
    up_delay = 5
  }
}

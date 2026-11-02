# CT 112 - scripts: small scheduled jobs (systemd timers), e.g. the swim-lesson watcher. LAN only.
# Nothing in here needs Docker, a GPU or bind mounts, so it stays tiny.
resource "proxmox_virtual_environment_container" "scripts" {
  lifecycle {
    ignore_changes = [operating_system[0].template_file_id, initialization[0].user_account]
  }

  node_name     = "pve"
  vm_id         = 112
  unprivileged  = true
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

  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }

  initialization {
    hostname = "scripts"

    dns {
      servers = ["1.1.1.1"] # public resolver: jobs keep working while Pi-hole is down
    }

    ip_config {
      ipv4 {
        address = "192.168.0.25/24"
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
    order    = 10
    up_delay = 5
  }
}

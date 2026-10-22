# CT 108 - games: JunimoServer (Stardew Valley dedicated server) in Docker
resource "proxmox_virtual_environment_container" "games" {
  lifecycle {
    ignore_changes = [operating_system[0].template_file_id, initialization[0].user_account]
  }

  node_name     = "pve"
  vm_id         = 108
  unprivileged  = true # Docker works unprivileged with nesting + keyctl
  start_on_boot = true
  started       = true

  cpu {
    cores = 4
  }

  memory {
    dedicated = 6144
    swap      = 1024
  }

  disk {
    datastore_id = "local-zfs"
    size         = 24
  }

  features {
    nesting = true
    keyctl  = true # needed for Docker in an unprivileged CT
  }

  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }

  initialization {
    hostname = "games"

    dns {
      servers = ["1.1.1.1"] # independent of Pi-hole so Steam lookups never get blocked
    }

    ip_config {
      ipv4 {
        address = "192.168.0.22/24"
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
    order    = 10 # after everything else
    up_delay = 5
  }
}

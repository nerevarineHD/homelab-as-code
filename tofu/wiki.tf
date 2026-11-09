# CT 115 - wiki: builds the lab wiki (docs/ + project repos) with MkDocs and serves it with
# nginx on the LAN only. Never behind Caddy: the wiki holds the network map, and every name
# Caddy serves is reachable from the internet.
resource "proxmox_virtual_environment_container" "wiki" {
  lifecycle {
    ignore_changes = [operating_system[0].template_file_id, initialization[0].user_account]
  }

  node_name     = "pve"
  vm_id         = 115
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024
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
    hostname = "wiki"

    dns {
      servers = ["1.1.1.1"] # public resolver: builds keep working while Pi-hole is down
    }

    ip_config {
      ipv4 {
        address = "192.168.0.28/24"
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

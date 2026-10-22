# CT 107 - reverse proxy (Caddy) on the DMZ, VLAN 30
resource "proxmox_virtual_environment_container" "proxy" {
  lifecycle {
    ignore_changes = [operating_system[0].template_file_id, initialization[0].user_account]
  }

  node_name     = "pve"
  vm_id         = 107
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024
    swap      = 512
  }

  disk {
    datastore_id = "local-zfs"
    size         = 8
  }

  features {
    nesting = true
  }

  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }

  initialization {
    hostname = "proxy"

    dns {
      servers = ["192.168.0.20"] # Pi-hole, reachable from the DMZ by ACL rule 1
    }

    ip_config {
      ipv4 {
        address = "192.168.30.10/24" # below the DMZ DHCP pool (.50-.254)
        gateway = "192.168.30.1"
      }
    }

    user_account {
      keys = [local.ansible_ssh_key]
    }
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    vlan_id  = 30
    firewall = true
  }

  startup {
    order    = 6
    up_delay = 5
  }
}

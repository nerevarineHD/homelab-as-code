# CT 109 - Valheim dedicated server (Docker) on the DMZ, VLAN 30
resource "proxmox_virtual_environment_container" "valheim" {
  lifecycle {
    ignore_changes = [operating_system[0].template_file_id, initialization[0].user_account]
  }

  node_name     = "pve"
  vm_id         = 109
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = 4
  }

  memory {
    dedicated = 8192
    swap      = 1024
  }

  disk {
    datastore_id = "local-zfs"
    size         = 32
  }

  features {
    nesting = true # Docker in an unprivileged LXC
    keyctl  = true
  }

  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }

  initialization {
    hostname = "valheim"

    dns {
      servers = ["192.168.0.20"] # Pi-hole, reachable from the DMZ by ACL rule 1
    }

    ip_config {
      ipv4 {
        address = "192.168.30.11/24"
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
    order    = 7
    up_delay = 15
  }
}

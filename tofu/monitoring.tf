# __generated__ by OpenTofu
# Please review these resources and move them into your main configuration files.

# __generated__ by OpenTofu
resource "proxmox_virtual_environment_container" "monitoring" {
  lifecycle {
    ignore_changes = [operating_system[0].template_file_id, initialization[0].user_account]
  }

  delete_unreferenced_disks_on_destroy = false
  description                          = ""
  environment_variables                = {}
  hook_script_file_id                  = ""
  node_name                            = "pve"
  pool_id                              = null
  protection                           = false
  purge_on_destroy                     = true
  start_on_boot                        = true
  started                              = true
  tags                                 = []
  template                             = false
  timeout_clone                        = null
  timeout_create                       = null
  timeout_delete                       = null
  timeout_update                       = null
  unprivileged                         = false
  vm_id                                = 104
  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }
  cpu {
    architecture = "amd64"
    cores        = 2
    limit        = 0
  }
  disk {
    acl           = false
    datastore_id  = "local-zfs"
    mount_options = []
    quota         = false
    replicate     = false
    size          = 20
  }
  features {
    fuse    = false
    keyctl  = true
    mknod   = false
    mount   = []
    nesting = true
  }
  initialization {
    user_account {
      keys = [local.ansible_ssh_key]
    }
    hostname = "monitoring"
    dns {
      domain  = ""
      servers = ["1.1.1.1", "8.8.8.8"]
    }
    ip_config {
      ipv4 {
        address = "192.168.0.15/24"
        gateway = "192.168.0.1"
      }
    }
  }
  memory {
    dedicated = 4096
    swap      = 512
  }
  network_interface {
    bridge       = "vmbr0"
    enabled      = true
    firewall     = true
    host_managed = false
    mac_address  = "BC:24:11:75:40:31"
    mtu          = 0
    name         = "eth0"
    rate_limit   = 0
    vlan_id      = 0
  }
  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }
}

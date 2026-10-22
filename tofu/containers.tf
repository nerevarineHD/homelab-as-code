# __generated__ by OpenTofu
# Please review these resources and move them into your main configuration files.

# __generated__ by OpenTofu
resource "proxmox_virtual_environment_container" "downloader" {
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
  vm_id                                = 102
  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }
  cpu {
    architecture = "amd64"
    cores        = 4
    limit        = 0
  }
  device_passthrough {
    deny_write = false
    gid        = 0
    mode       = "0660"
    path       = "/dev/net/tun"
    uid        = 0
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
    hostname = "downloader"
    dns {
      domain  = ""
      servers = ["1.1.1.1", "8.8.8.8"]
    }
    ip_config {
      ipv4 {
        address = "192.168.0.13/24"
        gateway = "192.168.0.1"
      }
    }
  }
  memory {
    dedicated = 6144
    swap      = 512
  }
  mount_point {
    acl           = false
    backup        = false
    mount_options = []
    path          = "/mnt/downloads"
    quota         = false
    read_only     = false
    replicate     = true
    shared        = false
    size          = ""
    volume        = "/media/downloads"
  }
  mount_point {
    acl           = false
    backup        = false
    mount_options = []
    path          = "/mnt/media"
    quota         = false
    read_only     = false
    replicate     = true
    shared        = false
    size          = ""
    volume        = "/media/library"
  }
  network_interface {
    bridge       = "vmbr0"
    enabled      = true
    firewall     = true
    host_managed = false
    mac_address  = "BC:24:11:D5:AF:2E"
    mtu          = 0
    name         = "eth0"
    rate_limit   = 0
    vlan_id      = 0
  }
  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }
  startup {
    down_delay = -1
    order      = 3
    up_delay   = 15
  }
}

# __generated__ by OpenTofu
resource "proxmox_virtual_environment_container" "omada" {
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
  vm_id                                = 103
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
    size          = 16
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
    hostname = "omada"
    dns {
      domain  = ""
      servers = ["1.1.1.1", "8.8.8.8"]
    }
    ip_config {
      ipv4 {
        address = "192.168.0.30/24"
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
    mac_address  = "BC:24:11:65:83:0B"
    mtu          = 0
    name         = "eth0"
    rate_limit   = 0
    vlan_id      = 0
  }
  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }
  startup {
    down_delay = -1
    order      = 4
    up_delay   = 15
  }
}

# __generated__ by OpenTofu
resource "proxmox_virtual_environment_container" "plex" {
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
  vm_id                                = 101
  console {
    enabled   = true
    tty_count = 2
    type      = "tty"
  }
  cpu {
    architecture = "amd64"
    cores        = 4
    limit        = 0
  }
  disk {
    acl           = false
    datastore_id  = "local-zfs"
    mount_options = []
    quota         = false
    replicate     = false
    size          = 32
  }
  initialization {
    user_account {
      keys = [local.ansible_ssh_key]
    }
    hostname = "plex"
    ip_config {
      ipv4 {
        address = "192.168.0.12/24"
        gateway = "192.168.0.1"
      }
    }
  }
  memory {
    dedicated = 4096
    swap      = 2048
  }
  mount_point {
    acl           = false
    backup        = false
    mount_options = []
    path          = "/mnt/media"
    quota         = false
    read_only     = true
    replicate     = true
    shared        = false
    size          = ""
    volume        = "/media/library"
  }
  network_interface {
    bridge       = "vmbr0"
    enabled      = true
    firewall     = true
    host_managed = false
    mac_address  = "BC:24:11:18:C7:1A"
    mtu          = 0
    name         = "eth0"
    rate_limit   = 0
    vlan_id      = 0
  }
  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }
  startup {
    down_delay = -1
    order      = 2
    up_delay   = 15
  }
}

# __generated__ by OpenTofu
resource "proxmox_virtual_environment_container" "storage" {
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
  vm_id                                = 100
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
    size          = 8
  }
  initialization {
    user_account {
      keys = [local.ansible_ssh_key]
    }
    hostname = "storage"
    ip_config {
      ipv4 {
        address = "192.168.0.11/24"
        gateway = "192.168.0.1"
      }
    }
  }
  memory {
    dedicated = 1024
    swap      = 512
  }
  mount_point {
    acl           = false
    backup        = false
    mount_options = []
    path          = "/srv/media"
    quota         = false
    read_only     = false
    replicate     = true
    shared        = false
    size          = ""
    volume        = "/media/library"
  }
  mount_point {
    acl           = false
    backup        = false
    mount_options = []
    path          = "/srv/games"
    quota         = false
    read_only     = false
    replicate     = true
    shared        = false
    size          = ""
    volume        = "/bulk/games"
  }
  mount_point {
    acl           = false
    backup        = false
    mount_options = []
    path          = "/srv/random"
    quota         = false
    read_only     = false
    replicate     = true
    shared        = false
    size          = ""
    volume        = "/bulk/random"
  }
  network_interface {
    bridge       = "vmbr0"
    enabled      = true
    firewall     = true
    host_managed = false
    mac_address  = "BC:24:11:A6:DE:DC"
    mtu          = 0
    name         = "eth0"
    rate_limit   = 0
    vlan_id      = 0
  }
  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }
  startup {
    down_delay = -1
    order      = 1
    up_delay   = 15
  }
}

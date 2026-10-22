# CT 106 - Jellyfin (main media server, public via Caddy; reads the library read-only; NVENC GPU)
resource "proxmox_virtual_environment_container" "jellyfin" {
  lifecycle {
    ignore_changes = [operating_system[0].template_file_id, initialization[0].user_account]
  }

  node_name     = "pve"
  vm_id         = 106
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = 4
  }

  memory {
    dedicated = 4096
    swap      = 512
  }

  disk {
    datastore_id = "local-zfs"
    size         = 24
  }

  features {
    nesting = true
  }

  mount_point {
    volume    = "/media/library"
    path      = "/mnt/media"
    read_only = true
  }

  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }

  initialization {
    hostname = "jellyfin"

    dns {
      servers = ["1.1.1.1"]
    }

    ip_config {
      ipv4 {
        address = "192.168.0.21/24"
        gateway = "192.168.0.1"
      }
    }

    user_account {
      keys = [local.ansible_ssh_key]
    }
  }

  # GPU (RTX 2060 Super): NVENC/NVDEC transcoding
  dynamic "device_passthrough" {
    for_each = local.nvidia_devices
    content {
      path = device_passthrough.value
      mode = "0666"
    }
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = true
  }

  startup {
    order    = 5
    up_delay = 15
  }
}

# CT 110 - ai: Ollama (local models on the RTX 2060 Super) + Open WebUI (chat UI, also OpenRouter). LAN only.
resource "proxmox_virtual_environment_container" "ai" {
  lifecycle {
    ignore_changes = [operating_system[0].template_file_id, initialization[0].user_account]
  }

  node_name     = "pve"
  vm_id         = 110
  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = 6
  }

  memory {
    dedicated = 12288 # models bigger than the GPU's 8 GB spill into RAM
    swap      = 512
  }

  disk {
    datastore_id = "local-zfs"
    size         = 64 # model files are 2-8 GB each
  }

  features {
    nesting = true # Docker (Open WebUI)
    keyctl  = true
  }

  operating_system {
    template_file_id = local.ct_template
    type             = "debian"
  }

  initialization {
    hostname = "ai"

    dns {
      servers = ["1.1.1.1"]
    }

    ip_config {
      ipv4 {
        address = "192.168.0.23/24"
        gateway = "192.168.0.1"
      }
    }

    user_account {
      keys = [local.ansible_ssh_key]
    }
  }

  # GPU (RTX 2060 Super, shared with Jellyfin's NVENC): CUDA for Ollama
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
    order    = 8
    up_delay = 15
  }
}

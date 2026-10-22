terraform {
  required_version = ">= 1.8"
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

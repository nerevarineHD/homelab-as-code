# Auth: root@pam + password from env (PROXMOX_VE_USERNAME / PROXMOX_VE_PASSWORD).
# API tokens can't set bind mounts or privileged-CT features, so a password login is required.
provider "proxmox" {
  endpoint = "https://192.168.0.10:8006/"
  insecure = true # Proxmox's self-signed certificate
}

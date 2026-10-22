variable "ssh_pubkey_file" {
  description = "Public key baked into new containers for Ansible. CI points this at a throwaway key."
  type        = string
  default     = "/root/.ssh/id_ed25519.pub"
}

locals {
  # Used only when a container is created (e.g. rebuilding after a disaster);
  # ignored for existing containers via lifecycle.ignore_changes.
  ct_template     = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  ansible_ssh_key = trimspace(file(var.ssh_pubkey_file))
}

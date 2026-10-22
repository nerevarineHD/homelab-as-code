# Usage: source /root/homelab/scripts/tofu-env.sh
export PROXMOX_VE_USERNAME='root@pam'
read -rsp 'Proxmox root password: ' PROXMOX_VE_PASSWORD; echo; export PROXMOX_VE_PASSWORD
CLOUDFLARE_API_TOKEN=$(cd /root/homelab/ansible && ansible-vault view group_vars/all/vault.yml \
  | awk '$1=="vault_cloudflare_tofu_token:" {print $2}' | tr -d "\"'")
export CLOUDFLARE_API_TOKEN
echo "tofu env ready (Cloudflare token length: ${#CLOUDFLARE_API_TOKEN})"

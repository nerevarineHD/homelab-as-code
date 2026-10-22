#!/bin/bash
# collect.sh - capture the running homelab config into the git repo.
# Safe to re-run: it rebuilds the captured folders (host/, proxmox/, cts/)
# from the live system and leaves everything else in the repo alone.
# It never commits or pushes - review first, then commit yourself.

set -uo pipefail

REPO=/root/homelab
REMOTE=git@github.com:<you>/homelab.git

# CT id -> folder name
declare -A CTS=( [100]=storage [101]=plex [102]=downloader [103]=omada [104]=monitoring [105]=dns [106]=jellyfin [107]=proxy [108]=games [109]=valheim )

# App files to capture inside each CT (paths relative to /, globs/find allowed)
declare -A CT_FILES=(
  [100]="etc/samba/smb.conf"
  [101]="etc/crypto-policies/back-ends/apt-sequoia.config etc/apt/sources.list.d"
  [102]="\$(find opt/downloader -maxdepth 2 -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.toml' -o -name '.env' \))"
  [103]="opt/omada/docker-compose.yml"
  [104]="\$(find opt/monitoring -maxdepth 2 -type f \( -name '*.yml' -o -name '*.yaml' \))"
  [105]="etc/unbound/unbound.conf.d"   # not etc/pihole/pihole.toml: holds pwhash, which the scrubber misses
  [106]="etc/jellyfin"
  [108]="opt/stardew/docker-compose.yml opt/stardew/docker-compose.override.yml opt/stardew/.env opt/stardew/.local-container/settings/server-settings.json"
  [107]="etc/caddy/Caddyfile etc/crowdsec/acquis.d etc/crowdsec/config.yaml.local"
  [109]="opt/valheim/docker-compose.yml opt/ddns/docker-compose.yml"
)

# Per-CT system tweaks worth keeping everywhere (IPv6 workarounds etc.)
COMMON='etc/gai.conf etc/sysctl.d $(grep -l -s ForceIPv4 etc/apt/apt.conf.d/* || true)'

say()  { printf '\n== %s\n' "$*"; }
warn() { printf '   !! %s\n' "$*"; }

# ---------------------------------------------------------------- repo setup
mkdir -p "$REPO" && cd "$REPO" || exit 1
if [ ! -d .git ]; then
  say "Initialising repo"
  git init -q -b main
  git remote add origin "$REMOTE"
fi

[ -f .gitignore ] || cat > .gitignore <<'EOF'
# never commit real secrets or app data
.env
*.env
!*.env.example
**/data/
*.db
*.sqlite*
*.key
*.pem
EOF

[ -f README.md ] || cat > README.md <<'EOF'
# homelab

Configuration for a single-node Proxmox VE home lab: ZFS storage, Plex,
an automated media stack with Discord requests, and Prometheus/Grafana/
Uptime Kuma monitoring.

- `host/`     - files from the Proxmox host (sanoid, backup job, watchdog, exporters)
- `proxmox/`  - container definitions and cluster config from /etc/pve
- `cts/`      - config captured from inside each container
- `scripts/`  - helper scripts (this collector, etc.)

Captured by `scripts/collect.sh`. Secrets are replaced with `REDACTED`.
EOF

rm -rf host proxmox cts

# ---------------------------------------------------------------- host files
say "Host"
for f in \
  /etc/sanoid/sanoid.conf \
  /usr/local/sbin/backup-replicate.sh \
  /etc/systemd/system/backup-replicate.service \
  /etc/systemd/system/backup-replicate.timer \
  /etc/systemd/system/zfs_exporter.service \
  /etc/default/pve-ha-manager \
  /etc/default/prometheus-node-exporter \
  /etc/network/interfaces \
  /etc/apt/sources.list.d/debian-nonfree.sources
do
  if [ -f "$f" ]; then
    mkdir -p "host$(dirname "$f")" && cp -p "$f" "host$f"
  else
    warn "missing $f"
  fi
done

# ---------------------------------------------------------------- proxmox config
say "Proxmox"
mkdir -p proxmox/lxc
cp -p /etc/pve/lxc/*.conf proxmox/lxc/ 2>/dev/null || warn "no LXC configs found"
for f in storage.cfg jobs.cfg vzdump.cron; do
  [ -f "/etc/pve/$f" ] && cp -p "/etc/pve/$f" "proxmox/$f"
done
zpool list -o name,size,health > proxmox/zpool-list.txt 2>/dev/null
zfs list -o name,mountpoint,recordsize,compression,atime > proxmox/zfs-datasets.txt 2>/dev/null

# ---------------------------------------------------------------- container files
for id in "${!CTS[@]}"; do
  dest="cts/$id-${CTS[$id]}"
  say "CT $id (${CTS[$id]})"
  if [ "$(pct status "$id" 2>/dev/null | awk '{print $2}')" != "running" ]; then
    warn "CT $id is not running - skipped"
    continue
  fi
  mkdir -p "$dest"
  # tar the listed paths inside the CT and unpack them here, keeping the layout
  pct exec "$id" -- sh -c "cd / && tar -cf - \$(ls -d ${CT_FILES[$id]} $COMMON 2>/dev/null) 2>/dev/null" \
    | tar -xf - -C "$dest" 2>/dev/null
  [ -z "$(ls -A "$dest")" ] && warn "nothing captured from CT $id"
done

# ---------------------------------------------------------------- scrub secrets
say "Scrubbing secrets"
# .env files -> .env.example with every value replaced
while IFS= read -r -d '' envf; do
  sed -E 's/^([A-Za-z_][A-Za-z0-9_]*)=.*/\1=CHANGEME/' "$envf" > "${envf}.example"
  rm -f "$envf"
  echo "   $envf -> .env.example"
done < <(find host proxmox cts -type f -name '.env' -print0)

# key/value secrets in config files (leaves ${VAR} references alone)
find host proxmox cts -type f ! -name '*.example' -print0 | xargs -0 -r perl -pi -e 'next if /passwd chat/i;
  s/((?:password|passwd|pass|token|secret|api[_-]?key|apikey)\w*\s*[:=]\s*)(?!\$\{)(["\x27]?)[^\s"\x27#]+\2/$1$2REDACTED$2/ig;
  s#https://(?:\w+\.)?discord(?:app)?\.com/api/webhooks/\S+#https://discord.com/api/webhooks/REDACTED#g;
  s#(/api/push/)[A-Za-z0-9]+#$1REDACTED#g;
'

# ---------------------------------------------------------------- keep a copy of this script
mkdir -p scripts
[ "$(readlink -f "$0")" != "$REPO/scripts/collect.sh" ] && cp -p "$0" scripts/collect.sh

# ---------------------------------------------------------------- report
say "Done. Review before committing:"
echo "   cd $REPO && git status"
echo "   grep -rniE 'passw|token|secret|api.?key|webhook' --exclude-dir=.git . | grep -v REDACTED"

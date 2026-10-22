#!/bin/bash
# publish-public.sh - build the public showcase repo (homelab-as-code) from this private repo.
#
#   scripts/publish-public.sh            # dry run: build, scrub, scan, show what would change
#   scripts/publish-public.sh --push     # same, then commit and push to the public repo
#
# One-way: the private repo is the source of truth. The public repo gets an allowlist of
# files, real domains swapped for example domains, a vault.example.yml with key names only,
# and nothing else. Any check failing stops the run before anything is committed.

set -euo pipefail

PRIVATE=${PRIVATE:-/root/homelab}
PUBLIC=${PUBLIC:-/root/homelab-public}               # clone of the public repo
PUBLIC_REMOTE=git@github.com:nerevarineHD/homelab-as-code.git
DEPLOY_KEY=${DEPLOY_KEY:-/root/.ssh/github_homelab_public}
VAULT=$PRIVATE/ansible/group_vars/all/vault.yml
PUSH=0; [ "${1:-}" = "--push" ] && PUSH=1

# What goes public. Everything else (host/, proxmox/, cts/ snapshots, the vault) stays private.
ALLOW=(tofu ansible scripts .github .gitignore renovate.json)
EXCLUDE=(
  --exclude=.git --exclude=.terraform/ --exclude='*.tfstate*'
  --exclude=ansible/group_vars/all/vault.yml
  --exclude='*.vault'                      # vault-encrypted files (restic password, rclone config)
  --exclude='*.private.conf'               # the scrub terms themselves
)

# Private terms (the real names to swap out and to block) live in a file that is itself never
# published, so this script can be public without listing what it hides.
CONF=$PRIVATE/scripts/publish.private.conf
[ -f "$CONF" ] || { echo "!! missing $CONF" >&2; exit 1; }
# shellcheck source=/dev/null
. "$CONF"       # sets SCRUB (sed script) and FORBIDDEN (regex)
FORBIDDEN="$FORBIDDEN"'|[$]ANSIBLE_VAULT[;]|BEGIN [A-Z ]*PRIVATE KEY|discord(app)?\.com/api/webhooks/[0-9]'

say() { printf '\n== %s\n' "$*"; }
die() { printf '\n!! %s\n' "$*" >&2; exit 1; }

command -v gitleaks >/dev/null || die "gitleaks not installed (the pve_host role installs it)"
command -v rsync    >/dev/null || die "rsync not installed"

cd "$PRIVATE"
[ -z "$(git status --porcelain)" ] || die "private repo has uncommitted changes; commit first so the public copy matches a real commit"
SHA=$(git rev-parse --short HEAD)

STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
say "Staging allowlist from $PRIVATE @ $SHA"
rsync -a "${EXCLUDE[@]}" "${ALLOW[@]}" "$STAGE/"
cp -a public/. "$STAGE/"                        # public README, LICENSE, docs

say "Vault -> vault.example.yml (key names only, values never leave the vault)"
(cd "$PRIVATE/ansible" && ansible-vault view "$VAULT") | python3 -c '
import sys, yaml
keys = sorted((yaml.safe_load(sys.stdin) or {}).keys())
print("# Copy to vault.yml, fill in, then: ansible-vault encrypt vault.yml")
for k in keys: print(f"{k}: CHANGE_ME")
' > "$STAGE/ansible/group_vars/all/vault.example.yml"
grep -c ': CHANGE_ME' "$STAGE/ansible/group_vars/all/vault.example.yml" | sed 's/^/   keys: /'

say "Scrubbing domains and zone IDs"
grep -rlIZ . "$STAGE" | xargs -0 sed -i -E "$SCRUB"
sed -i -E 's/"[0-9a-f]{32}"/"00000000000000000000000000000000"/' "$STAGE/tofu/cloudflare-dns.tf"
sed -i -E 's#nerevarineHD/homelab\.git#<you>/homelab.git#' "$STAGE/scripts/collect.sh"
tofu fmt -recursive "$STAGE/tofu" >/dev/null     # renamed keys change HCL alignment

say "Checking for anything that must not be public"
if grep -rInEi "$FORBIDDEN" "$STAGE"; then die "forbidden strings above; fix the scrub or the source"; fi
if find "$STAGE" -name 'vault.yml' -o -name '*.tfstate*' -o -name '.env' | grep .; then die "secret-bearing files above"; fi
gitleaks dir --no-banner --redact "$STAGE" || die "gitleaks found something"
echo "   clean"

say "Syncing into $PUBLIC"
export GIT_SSH_COMMAND="ssh -i $DEPLOY_KEY -o IdentitiesOnly=yes"
if [ ! -d "$PUBLIC/.git" ]; then
  git clone -q "$PUBLIC_REMOTE" "$PUBLIC" 2>/dev/null || { mkdir -p "$PUBLIC"; git -C "$PUBLIC" init -q -b main; git -C "$PUBLIC" remote add origin "$PUBLIC_REMOTE"; }
fi
rsync -a --delete --exclude=.git "$STAGE/" "$PUBLIC/"
cd "$PUBLIC"
git add -A
if git diff --cached --quiet; then echo "   public repo already up to date"; exit 0; fi
git diff --cached --stat | tail -25

if [ $PUSH -eq 0 ]; then
  git reset -q
  say "Dry run only. Review $PUBLIC, then re-run with --push"
  exit 0
fi

git -c user.name="nerevarineHD" -c user.email="26617250+nerevarineHD@users.noreply.github.com" \
  commit -q -m "Sync from private repo ($(date +%F), $SHA)"
git push -q origin main
say "Published $(git rev-parse --short HEAD)"

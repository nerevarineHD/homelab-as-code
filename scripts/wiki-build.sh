#!/bin/bash
# wiki-build.sh - build the lab wiki from this repo plus each project repo's docs.
#
#   scripts/wiki-build.sh              # pull projects, check changelog entries, mkdocs build --strict
#   scripts/wiki-build.sh --no-pull    # use whatever is already in docs/projects/
#
# Needs: git, python3, mkdocs-material. Output: site/ (HTML) and wiki-export/ (plain Markdown
# for the Open WebUI knowledge base). Both are git-ignored, as is docs/projects/.
# The wiki holds the network map: serve it on the LAN only, never through a public name.

set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
CACHE=${WIKI_CACHE:-$REPO/.wiki-cache}          # clones of the project repos (git-ignored via .wiki-cache below)
PULL=1; [ "${1:-}" = "--no-pull" ] && PULL=0

# name|clone URL|paths to copy (relative to that repo). Markdown only; artifacts/ and code stay out.
PROJECTS=(
  "own-your-glass|${OWN_YOUR_GLASS_URL:-git@github.com:nerevarineHD/own-your-glass.git}|README.md AGENTS.md docs research"
)

say() { printf '\n== %s\n' "$*"; }
die() { printf '\n!! %s\n' "$*" >&2; exit 1; }

cd "$REPO"
command -v mkdocs >/dev/null || die "mkdocs not installed (pip install -r requirements-docs.txt)"

say "Checking changelog entries"
python3 hooks/changelog.py > /dev/null

mkdir -p "$CACHE" docs/projects
for p in "${PROJECTS[@]}"; do
  IFS='|' read -r name url paths <<< "$p"
  if [ "$PULL" = 1 ]; then
    say "Updating $name"
    if [ -d "$CACHE/$name/.git" ]; then
      git -C "$CACHE/$name" pull -q --ff-only
    else
      git clone -q --depth 1 "$url" "$CACHE/$name"
    fi
  fi
  [ -d "$CACHE/$name" ] || die "$name not cloned; run without --no-pull"
  rm -rf "docs/projects/$name"; mkdir -p "docs/projects/$name"
  for path in $paths; do
    [ -e "$CACHE/$name/$path" ] || continue
    if [ -d "$CACHE/$name/$path" ]; then
      (cd "$CACHE/$name" && find "$path" -name '*.md' -print0 | xargs -0 -I{} cp --parents {} "$REPO/docs/projects/$name/")
    else
      cp "$CACHE/$name/$path" "docs/projects/$name/"
    fi
  done
  echo "   $name @ $(git -C "$CACHE/$name" rev-parse --short HEAD)"
done

say "Building site"
mkdocs build --strict --quiet
echo "   site/ ok"

say "Writing plain-Markdown export"
rm -rf wiki-export; mkdir -p wiki-export
(cd docs && find . -name '*.md' -not -path './changelog/*' -print0 | xargs -0 -I{} cp --parents {} ../wiki-export/)
mkdir -p wiki-export/changelog
python3 hooks/changelog.py > wiki-export/changelog/index.md
echo "   wiki-export/ ok ($(find wiki-export -name '*.md' | wc -l) pages)"

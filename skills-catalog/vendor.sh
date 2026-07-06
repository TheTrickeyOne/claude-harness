#!/usr/bin/env bash
# vendor.sh — fetch the public skills this harness vendors.
#
# Clones each upstream repo (shallow) into _vendored/.cache/, then you cherry-
# pick the specific skill directory into the matching _vendored/<LICENSE>/ dir
# and keep its LICENSE + a line in ATTRIBUTION.md. We do NOT auto-copy whole
# repos — vendoring is deliberate and per-skill so licenses stay clean.
#
# Usage:  bash skills-catalog/vendor.sh [name ...]   (default: all)
# Run from the repo root. Requires git. Pinned commits live in ATTRIBUTION.md;
# update PINS below when you re-pin.

set -euo pipefail

case "${1:-}" in
  -h|--help)
    cat <<'EOF'
vendor.sh — shallow-clone the public skill repos this harness vendors.

Usage:
  bash skills-catalog/vendor.sh [NAME ...]     (default: all repos)
  bash skills-catalog/vendor.sh -h | --help

Clones each upstream repo into the gitignored _vendored/.cache/. You then
cherry-pick the specific skill dir into _vendored/<LICENSE>/, keep its LICENSE,
and record it in ATTRIBUTION.md. Whole repos are never auto-copied — vendoring
is deliberate and per-skill so licenses stay clean.

Args:
  NAME ...   One or more repo keys to fetch (e.g. superpowers trailofbits).
             Omit to fetch all. Keys are the first field of the REPOS list.

Requires git. Run from anywhere (self-cd's to skills-catalog/).
EOF
    exit 0
    ;;
esac

cd "$(dirname "${BASH_SOURCE[0]}")"
CACHE="_vendored/.cache"   # gitignored (see .gitignore)
mkdir -p "$CACHE"

# name|repo-url|license-bucket|skill-subpath-hint
REPOS=(
  "superpowers|https://github.com/obra/superpowers|MIT|skills/"
  "anthropic-skills|https://github.com/anthropics/skills|APACHE|skills/"
  "security-review|https://github.com/anthropics/claude-code-security-review|MIT|."
  "trailofbits|https://github.com/trailofbits/skills|CC-BY-SA|."
  "pentest-agents|https://github.com/0xSteph/pentest-ai-agents|MIT|."
  "cyber-ref|https://github.com/mukul975/Anthropic-Cybersecurity-Skills|APACHE|."
  "vercel-agent-skills|https://github.com/vercel-labs/agent-skills|MIT|."
  "web-quality|https://github.com/addyosmani/web-quality-skills|MIT|."
  "hashicorp|https://github.com/hashicorp/agent-skills|MPL|."
  "terraform-skill|https://github.com/antonbabenko/terraform-skill|APACHE|."
  "kubernetes-skill|https://github.com/LukasNiessen/kubernetes-skill|MIT|."
  "cc-devops|https://github.com/akin-ozer/cc-devops-skills|APACHE|."
  "ha-skill|https://github.com/komal-SkyNET/claude-skill-homeassistant|MIT|."
  "aurora-esphome|https://github.com/tonylofgren/aurora-smart-home|MIT|."
  "ansible-skills|https://github.com/leogallego/claude-ansible-skills|GPL|."
  "esp32-workbench|https://github.com/agodianel/esp32-claude-workbench|MIT|."
  "zephyr-skills|https://github.com/beriberikix/zephyr-agent-skills|APACHE|."
  "embeddedskills|https://github.com/zhinkgit/embeddedskills|MIT|."
)

fetch_one() {
  local line="$1"
  IFS='|' read -r name url bucket hint <<<"$line"
  local dest="$CACHE/$name"
  if [[ -d "$dest/.git" ]]; then
    echo "== $name: already cloned (pull to update manually)"
  else
    echo "== $name: cloning $url"
    git clone --depth 1 "$url" "$dest"
  fi
  echo "   license bucket: $bucket   skill hint: $hint"
  echo "   -> cherry-pick the wanted skill dir into _vendored/$bucket/ and record it in ATTRIBUTION.md"
}

want=("$@")
for line in "${REPOS[@]}"; do
  name="${line%%|*}"
  if [[ ${#want[@]} -eq 0 ]]; then
    fetch_one "$line"
  else
    for w in "${want[@]}"; do
      [[ "$w" == "$name" ]] && fetch_one "$line"
    done
  fi
done

echo
echo "Done. Cache in $CACHE/ is gitignored. Copy only the specific skill dirs you"
echo "want into _vendored/<LICENSE>/, keep each LICENSE, and update ATTRIBUTION.md."
echo "Run NVIDIA/SkillSpector (or read the SKILL.md) on anything before enabling it."

#!/usr/bin/env bash
# convert.sh — expose this harness's skills to other agents.
#
# SKILL.md is portable; the main work is putting the skill dirs where each agent
# looks. This does the common layouts. Run from the repo root.
#
#   bash portable/convert.sh codex     # symlink skills into ~/.codex/skills
#   bash portable/convert.sh gemini    # copy skills into Gemini's skills dir
#   bash portable/convert.sh opencode  # copy skills into ~/.config/opencode
#
# For richer conversions (Gemini extension manifests, frontmatter->TOML) use a
# dedicated tool like jduncan-rva/skill-porter; this handles the 80% case.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."   # repo root

SRC=".claude/skills"
if [[ ! -d "$SRC" ]]; then
  echo "No $SRC yet — run /bootstrap first to populate enabled skills." >&2
  exit 1
fi

target="${1:-}"
case "$target" in
  codex)
    dest="$HOME/.codex/skills"
    mkdir -p "$dest"
    for d in "$SRC"/*/; do
      name="$(basename "$d")"
      ln -sfn "$PWD/$d" "$dest/$name"
      echo "linked $name -> $dest/$name"
    done
    ;;
  gemini)
    dest="${GEMINI_SKILLS_DIR:-$HOME/.gemini/skills}"
    mkdir -p "$dest"
    cp -R "$SRC"/. "$dest"/
    echo "copied skills to $dest (verify Gemini's skills path for your version)"
    ;;
  opencode)
    dest="$HOME/.config/opencode/skills"
    mkdir -p "$dest"
    cp -R "$SRC"/. "$dest"/
    echo "copied skills to $dest"
    ;;
  *)
    echo "usage: bash portable/convert.sh {codex|gemini|opencode}" >&2
    exit 2
    ;;
esac

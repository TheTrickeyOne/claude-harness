#!/usr/bin/env bash
# convert.sh — expose this harness's skills to other agents.
#
# SKILL.md is portable; the main work is putting the skill dirs where each agent
# looks. This does the common layouts. Self-cd's to the repo root, so it can be
# run from anywhere.
#
#   bash portable/convert.sh codex     # symlink skills into ~/.codex/skills
#   bash portable/convert.sh gemini    # copy skills into Gemini's skills dir
#   bash portable/convert.sh opencode  # copy skills into ~/.config/opencode
#
# For richer conversions (Gemini extension manifests, frontmatter->TOML) use a
# dedicated tool like jduncan-rva/skill-porter; this handles the 80% case.

set -euo pipefail
shopt -s nullglob                        # empty skills dir -> loop runs 0 times
cd "$(dirname "${BASH_SOURCE[0]}")/.."    # repo root

# Validate the target BEFORE checking for skills, so a typo/no-arg shows usage
# rather than the "run /bootstrap" hint.
target="${1:-}"
case "$target" in
  -h|--help)
    cat <<'EOF'
convert.sh — expose this harness's skills to another agent.

Usage:
  bash portable/convert.sh {codex|gemini|opencode}
  bash portable/convert.sh -h | --help

Targets:
  codex      symlink .claude/skills/* into ~/.codex/skills (live; tracks edits)
  gemini     copy .claude/skills into $GEMINI_SKILLS_DIR or ~/.gemini/skills
  opencode   copy .claude/skills into ~/.config/opencode/skills

Requires the project to be bootstrapped (.claude/skills/ present). Self-cd's to
the repo root, so it can be run from anywhere.
EOF
    exit 0
    ;;
  codex|gemini|opencode) ;;
  *)
    echo "usage: bash portable/convert.sh {codex|gemini|opencode}  (-h for help)" >&2
    exit 2
    ;;
esac

SRC=".claude/skills"
if [[ ! -d "$SRC" ]]; then
  echo "No $SRC yet — run /bootstrap first to populate enabled skills." >&2
  exit 1
fi

case "$target" in
  codex)
    dest="$HOME/.codex/skills"
    mkdir -p "$dest"
    count=0
    for d in "$SRC"/*/; do
      [[ -d "$d" ]] || continue          # guard against a stray glob match
      name="$(basename "$d")"
      ln -sfn "$PWD/$d" "$dest/$name"
      echo "linked $name -> $dest/$name"
      count=$((count + 1))
    done
    if [[ $count -eq 0 ]]; then
      echo "no skills in $SRC — nothing to link (run /bootstrap to populate)"
    fi
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
esac

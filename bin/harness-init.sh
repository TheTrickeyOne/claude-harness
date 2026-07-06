#!/usr/bin/env bash
# harness-init.sh — LIGHTWEIGHT init for a simple project.
#
# The full flow (degit -> /bootstrap -> trim) is for stack-heavy projects that
# want the curated skills, MCP wiring, and a tailored AGENTS.md. Most simple
# projects don't need it — the compound-command hook and your work-style prefs
# are already global in ~/.claude, so a bare `mkdir && git init && claude` is
# already covered.
#
# This adds the small "good habits" layer on top: AGENTS.md + a handful of core
# dev skills (a few KB, no 158MB vendored catalog, no interview, no MCP).
#
# Run from your canonical harness clone:
#   bash ~/src/claude-harness/bin/harness-init.sh [target-dir]
# target-dir defaults to the current directory.

set -euo pipefail
shopt -s nullglob

usage() {
  cat <<'EOF'
harness-init.sh — lightweight init for a simple project.

Usage:
  bash harness-init.sh [TARGET_DIR]
  bash harness-init.sh -h | --help

Adds AGENTS.md + CLAUDE.md (@AGENTS.md) + ~5 core dev skills
(test-driven-development, systematic-debugging, verification-before-completion,
git-pr-workflow, secrets-hygiene) and a secrets .gitignore. No vendored catalog,
no interview, no MCP. Existing AGENTS.md/CLAUDE.md are left untouched.

Args:
  TARGET_DIR   Directory to set up (created if missing). Defaults to cwd.

Run it from your canonical harness clone. For a stack-heavy project use the full
flow instead (see README: "Use in a project").
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

# Resolve the harness repo root (this script lives in <root>/bin/).
HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

target="${1:-.}"
mkdir -p "$target"
target="$(cd "$target" && pwd)"

echo "harness-init: minimal setup in $target"

# --- AGENTS.md (the stack-agnostic contract; keep an existing one) ---
if [[ -e "$target/AGENTS.md" ]]; then
  echo "  · AGENTS.md exists — left untouched"
else
  cp "$HARNESS_ROOT/AGENTS.md" "$target/AGENTS.md"
  echo "  · AGENTS.md added"
fi

# --- CLAUDE.md pointer (so Claude Code imports AGENTS.md) ---
if [[ -e "$target/CLAUDE.md" ]]; then
  echo "  · CLAUDE.md exists — left untouched"
else
  printf '@AGENTS.md\n' > "$target/CLAUDE.md"
  echo "  · CLAUDE.md added (@AGENTS.md)"
fi

# --- Core "good habits" skills (small, universal). Sources relative to root. ---
CORE_SKILLS=(
  "_vendored/MIT/superpowers-test-driven-development"
  "_vendored/MIT/superpowers-systematic-debugging"
  "_vendored/MIT/superpowers-verification-before-completion"
  "_custom/git-pr-workflow"
  "_custom/secrets-hygiene"
)
mkdir -p "$target/.claude/skills"
added=0
missing=()
for rel in "${CORE_SKILLS[@]}"; do
  src="$HARNESS_ROOT/skills-catalog/$rel"
  name="$(basename "$rel")"
  if [[ -d "$src" ]]; then
    cp -R "$src" "$target/.claude/skills/$name"
    added=$((added + 1))
  else
    missing+=("$rel")
  fi
done
echo "  · $added core skills copied to .claude/skills/"
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "  · note: missing in this clone (run vendor.sh?): ${missing[*]}"
fi

# --- .gitignore essentials (secrets), if none exists ---
if [[ ! -e "$target/.gitignore" ]]; then
  printf '.env\n.env.*\n!.env.example\n*.key\n*.pem\nkubeconfig\n.claude/settings.local.json\n' > "$target/.gitignore"
  echo "  · .gitignore added (secrets)"
fi

echo "done. Next: cd $target && git init && claude"
echo "For a stack-heavy project instead, use the full flow (README: Adopting into a project)."

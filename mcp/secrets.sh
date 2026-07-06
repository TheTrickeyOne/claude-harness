#!/usr/bin/env bash
# secrets.sh — the FALLBACK secrets seam (Layer 1).
#
# This is the no-manager path. The preferred path is Infisical `run` (Layer 2)
# and, for hardening, Agent Vault (Layer 3). See docs/secrets.md for the full
# layered model — READ THAT FIRST.
#
#   Preferred:  infisical run --projectId <id> --env prod -- claude
#   Fallback:   source mcp/secrets.sh   (then launch the agent)
#
# Source this so ${VAR} references in .mcp.json resolve from the environment.
# Backends (set HARNESS_SECRETS_BACKEND in .env):
#   env        values live literally in .env               (default, today)
#   1password  values in .env are op:// refs, resolved via `op read`
#   bitwarden  values in .env are Secrets Manager IDs, resolved via `bws secret get`
#
# Switching backends is a ONE-FILE change: only this script and the form of the
# values in .env change. .mcp.json and every skill stay identical.
#
# Caveats (see docs/secrets.md):
#   - Proton Pass has no secrets CLI — not a backend option.
#   - 1Password has no free tier.
#   - The `bitwarden` backend uses Bitwarden Secrets Manager (`bws`). This does
#     NOT work against self-hosted Vaultwarden (Vaultwarden implements only the
#     password-manager API; Secrets Manager stayed proprietary). For Vaultwarden
#     you'd add a `bw get`-based backend instead. Given Infisical is already
#     self-hosted here, prefer Layer 2 over any of these.

# --help works whether this is sourced or executed directly.
case "${1:-}" in
  -h|--help)
    cat <<'EOF'
secrets.sh — Layer-1 fallback secrets resolver.

Usage:
  source mcp/secrets.sh          then launch the agent (exports ${VAR}s)
  bash   mcp/secrets.sh -h|--help

SOURCE this (don't just run it) so the resolved secrets land in your shell and
${VAR} references in .mcp.json pick them up. Reads mcp/.env (or $HARNESS_ENV_FILE).
Backend is set by HARNESS_SECRETS_BACKEND in .env: env | 1password | bitwarden.

Preferred path is Infisical `run` (Layer 2), not this — see docs/secrets.md.
EOF
    return 0 2>/dev/null || exit 0
    ;;
esac

set -euo pipefail

_here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_envfile="${HARNESS_ENV_FILE:-$_here/.env}"

if [[ ! -f "$_envfile" ]]; then
  echo "secrets.sh: no .env at $_envfile (copy .env.example to .env)" >&2
  return 1 2>/dev/null || exit 1
fi

# The secret var names this harness manages. Keep in sync with .env.example.
_HARNESS_SECRET_VARS=(
  KUBECONFIG
  ARGOCD_BASE_URL ARGOCD_API_TOKEN
  GRAFANA_URL GRAFANA_SERVICE_ACCOUNT_TOKEN
  GITHUB_PERSONAL_ACCESS_TOKEN
  HA_URL HA_TOKEN
  CONTEXT7_API_KEY
  IDF_PATH
  NORDIC_API_KEY
  PROXMOX_HOST PROXMOX_TOKEN_ID PROXMOX_TOKEN_SECRET
)

# Load .env (values, plus the backend selector). Lines are VAR=value.
set -a
# shellcheck disable=SC1090
source "$_envfile"
set +a

_backend="${HARNESS_SECRETS_BACKEND:-env}"

_resolve_one() {
  # $1 = var name; reads its current (ref) value, exports the resolved secret.
  local name="$1"
  local ref="${!name:-}"
  [[ -z "$ref" ]] && return 0
  case "$_backend" in
    env)
      # already the literal value; nothing to do
      ;;
    1password)
      command -v op >/dev/null || { echo "secrets.sh: 'op' (1Password CLI) not found" >&2; return 1; }
      export "$name"="$(op read "$ref")"
      ;;
    bitwarden)
      command -v bws >/dev/null || { echo "secrets.sh: 'bws' (Bitwarden Secrets Manager CLI) not found" >&2; return 1; }
      export "$name"="$(bws secret get "$ref" | grep '"value"' | head -1 | cut -d'"' -f4)"
      ;;
    *)
      echo "secrets.sh: unknown HARNESS_SECRETS_BACKEND '$_backend'" >&2
      return 1
      ;;
  esac
}

for _v in "${_HARNESS_SECRET_VARS[@]}"; do
  _resolve_one "$_v"
done

echo "secrets.sh: resolved via '$_backend' backend" >&2

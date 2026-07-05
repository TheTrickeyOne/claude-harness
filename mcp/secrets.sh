#!/usr/bin/env bash
# secrets.sh — the single seam for MCP secrets.
#
# Source this BEFORE launching your agent so ${VAR} references in .mcp.json
# resolve from the process environment:
#
#     source mcp/secrets.sh && claude
#
# Backends (set HARNESS_SECRETS_BACKEND in .env):
#   env        values live literally in .env               (default, today)
#   1password  values in .env are op:// refs, resolved via `op read`
#   bitwarden  values in .env are BWS secret IDs, resolved via `bws secret get`
#
# Switching backends is a ONE-FILE change: only this script and the form of the
# values in .env change. .mcp.json and every skill stay identical.
#
# Proton Pass has no secrets CLI as of 2026-07, so it is not a backend option;
# stay on `env` or use 1Password/Bitwarden.

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

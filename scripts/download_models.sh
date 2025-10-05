#!/usr/bin/env bash
set -euo pipefail

: "${INVOKEAI_ROOT:?INVOKEAI_ROOT must be set}"
: "${CIVITAI_TOKEN:-}"

CHECKPOINT_DIR="${INVOKEAI_ROOT}/models/checkpoints"
LORA_DIR="${INVOKEAI_ROOT}/models/loras"
VAE_DIR="${INVOKEAI_ROOT}/models/vae"
mkdir -p "$CHECKPOINT_DIR" "$LORA_DIR" "$VAE_DIR"

# --- Colors ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# --- Counters ---
success_count=0
fail_count=0
warn_count=0

log() { printf "%b\n" "$*" >&2; }

split_list() {
  local raw="${1:-}"
  printf '%s' "$raw" | tr ',' '\n' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' | awk 'NF'
}

collect_numbered() {
  local prefix="$1"
  env | grep -E "^${prefix}[0-9]+=" | sort -t'_' -k3,3n | while IFS='=' read -r _ v; do
    printf '%s\n' "$v"
  done
}

uniq_stable() { awk '!seen[$0]++'; }

gather_urls() {
  local kind="$1"
  local upper="$kind" lower="${kind,,}"
  local single="${upper}_URL" list="${upper}_URLS" prefix="${upper}_URL_"
  {
    [ -n "${!single-}" ] && printf '%s\n' "${!single}"
    [ -n "${!list-}" ] && split_list "${!list}"
    collect_numbered "$prefix"
  } | uniq_stable
}

download_to_dir() {
  local url="$1" dest_dir="$2"
  [ -z "${url:-}" ] && return 0

  local retries=5 delay=2
  log "${YELLOW}→ Downloading:${NC} $url"

  local curl_opts=(-fL -C - -J -O --retry "$retries" --retry-delay "$delay" --output-dir "$dest_dir")
  if [ -n "${CIVITAI_TOKEN:-}" ]; then
    curl_opts+=(-H "Authorization: Bearer ${CIVITAI_TOKEN}" -H "Accept: application/octet-stream")
  fi

  if curl "${curl_opts[@]}" "$url"; then
    log "${GREEN}✓ Success${NC}"
    ((success_count++))
  else
    code=$?
    case "$code" in
      22) log "${RED}✗ HTTP error (likely 404 or token issue)${NC}" ;;
      28) log "${RED}✗ Timeout (network slow or Civitai down)${NC}" ;;
      56) log "${RED}✗ Connection aborted mid-transfer${NC}" ;;
      *)  log "${RED}✗ Unknown error code ${code}${NC}" ;;
    esac
    ((fail_count++))
    return 1
  fi
}

# === Process all model types ===
log "=== Downloading CHECKPOINTS ==="
gather_urls "CHECKPOINT" | while IFS= read -r u; do download_to_dir "$u" "$CHECKPOINT_DIR"; done || true

log "=== Downloading LORAS ==="
gather_urls "LORA" | while IFS= read -r u; do download_to_dir "$u" "$LORA_DIR"; done || true

log "=== Downloading VAEs ==="
gather_urls "VAE" | while IFS= read -r u; do download_to_dir "$u" "$VAE_DIR"; done || true

# --- Summary ---
log ""
if (( fail_count > 0 )); then
  log "${YELLOW}⚠️  Download summary:${NC}  ${GREEN}${success_count} OK${NC}, ${RED}${fail_count} failed${NC}"
else
  log "${GREEN}✓ All downloads complete (${success_count})${NC}"
fi

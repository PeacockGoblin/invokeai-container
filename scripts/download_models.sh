#!/usr/bin/env bash
set -euo pipefail

: "${INVOKEAI_ROOT:?INVOKEAI_ROOT must be set}"
: "${CIVITAI_TOKEN:-}"

CHECKPOINT_DIR="${INVOKEAI_ROOT}/models/checkpoints"
LORA_DIR="${INVOKEAI_ROOT}/models/loras"
VAE_DIR="${INVOKEAI_ROOT}/models/vae"
mkdir -p "$CHECKPOINT_DIR" "$LORA_DIR" "$VAE_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
success_count=0; fail_count=0

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
  local upper="$kind"
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

  log "${YELLOW}→ Downloading:${NC} $url"
  local wget_flags=(--content-disposition --trust-server-names -c --tries=5 --waitretry=2 -P "$dest_dir")

  if [ -n "${CIVITAI_TOKEN:-}" ]; then
    if wget "${wget_flags[@]}" \
        --header="Authorization: Bearer ${CIVITAI_TOKEN}" \
        --header="Accept: application/octet-stream" \
        "$url"; then
      log "${GREEN}✓ Success${NC}"; ((success_count++))
    else
      code=$?; log "${RED}✗ wget failed (exit ${code})${NC}"; ((fail_count++)); return 1
    fi
  else
    if wget "${wget_flags[@]}" "$url"; then
      log "${GREEN}✓ Success${NC}"; ((success_count++))
    else
      code=$?; log "${RED}✗ wget failed (exit ${code})${NC}"; ((fail_count++)); return 1
    fi
  fi
}

log "=== Downloading CHECKPOINTS ==="
gather_urls "CHECKPOINT" | while IFS= read -r u; do download_to_dir "$u" "$CHECKPOINT_DIR"; done || true

log "=== Downloading LORAS ==="
gather_urls "LORA" | while IFS= read -r u; do download_to_dir "$u" "$LORA_DIR"; done || true

log "=== Downloading VAEs ==="
gather_urls "VAE" | while IFS= read -r u; do download_to_dir "$u" "$VAE_DIR"; done || true

log ""
if (( fail_count > 0 )); then
  log "⚠️  Download summary: ${success_count} OK, ${fail_count} failed"
else
  log "${GREEN}✓ All downloads complete (${success_count})${NC}"
fi

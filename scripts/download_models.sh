#!/usr/bin/env bash
set -euo pipefail

# ===================== config & dirs =====================
: "${INVOKEAI_ROOT:?INVOKEAI_ROOT must be set}"
: "${CIVITAI_TOKEN:-}"  # optional for public files, required for many Civitai assets

CHECKPOINT_DIR="${INVOKEAI_ROOT}/models/checkpoints"
LORA_DIR="${INVOKEAI_ROOT}/models/loras"
VAE_DIR="${INVOKEAI_ROOT}/models/vae"
mkdir -p "$CHECKPOINT_DIR" "$LORA_DIR" "$VAE_DIR"

# ===================== logging ===========================
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
success_count=0; fail_count=0
log() { printf "%b\n" "$*" >&2; }

# ===================== helpers ===========================
split_list() {
  # Normalize comma/newline-separated env lists to one URL per line
  local raw="${1:-}"
  printf '%s' "$raw" \
    | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' \
    | awk 'NF'
}

collect_numbered() {
  # Read numbered envs like LORA_URL_1, LORA_URL_2... in numeric order
  local prefix="$1"
  env | grep -E "^${prefix}[0-9]+=" | sort -t'_' -k3,3n | while IFS='=' read -r _ v; do
    printf '%s\n' "$v"
  done
}

uniq_stable() { awk '!seen[$0]++'; }

gather_urls() {
  # Merge single, list, and numbered envs for a given kind: CHECKPOINT | LORA | VAE
  local kind="$1"
  local upper="$kind"
  local single="${upper}_URL"
  local list="${upper}_URLS"
  local prefix="${upper}_URL_"
  {
    [ -n "${!single-}" ] && printf '%s\n' "${!single}"
    [ -n "${!list-}" ] && split_list "${!list}"
    collect_numbered "$prefix"
  } | uniq_stable
}

url_pct_decode() {
  # percent-decode minimal set (%XX) without messing with plus signs
  # shellcheck disable=SC2018,SC2019
  python3 - "$1" <<'PY'
import sys, urllib.parse
print(urllib.parse.unquote(sys.argv[1]))
PY
}

sanitize_name() {
  # Keep alnum, dot, comma, underscore, dash, space → then collapse spaces to _
  # No locale-dependent ranges.
  printf '%s' "$1" | sed 's/[^A-Za-z0-9.,_ -]/_/g; s/[[:space:]]\{1,\}/_/g'
}

derive_filename() {
  # Best-effort short filename from URL; default extension if missing
  local url="$1" default_ext="${2:-safetensors}"

  # 1) Try filename from response-content-disposition=...filename="..."
  local enc
  enc="$(printf '%s' "$url" | sed -n 's/.*response-content-disposition=[^&]*filename%3D%22\([^%]*\).*/\1/p')"
  local fname=""
  if [ -n "${enc:-}" ]; then
    fname="$(url_pct_decode "$enc" 2>/dev/null || true)"
  fi

  # 2) Fallback: basename before '?'
  if [ -z "$fname" ]; then
    fname="$(basename "${url%%\?*}")"
  fi

  # 3) Fallback: synthesized
  if [ -z "$fname" ] || [ "$fname" = "/" ] || [ "$fname" = "." ]; then
    fname="model_$(date +%s).${default_ext}"
  fi

  # Ensure extension is reasonable
  case "$fname" in
    *.safetensors|*.pt|*.bin|*.ckpt|*.vae) : ;;
    *) fname="${fname%.*}.${default_ext}" ;;
  esac

  # Sanitize & clamp length
  fname="$(sanitize_name "$fname")"
  [ "${#fname}" -gt 160 ] && fname="model_$(date +%s).${default_ext}"

  printf '%s' "$fname"
}

curl_save() {
  # Curl with resume, retries, and fixed output filename
  local url="$1" out="$2"
  local opts=(-fL -C - --retry 5 --retry-delay 2 -o "$out")
  if [ -n "${CIVITAI_TOKEN:-}" ]; then
    opts+=(-H "Authorization: Bearer ${CIVITAI_TOKEN}" -H "Accept: application/octet-stream")
  fi
  curl "${opts[@]}" "$url"
}

download_to_dir() {
  local url="$1" dest_dir="$2" default_ext="${3:-safetensors}"
  [ -z "${url:-}" ] && return 0
  mkdir -p "$dest_dir"

  local fname out
  fname="$(derive_filename "$url" "$default_ext")"
  [ -z "$fname" ] && fname="model_$(date +%s).${default_ext}"
  out="${dest_dir}/${fname}"

  log "${YELLOW}→ Downloading:${NC} $url"
  log "   → Saving as: $out"

  if curl_save "$url" "$out"; then
    # sanity: >10MB
    if [ -s "$out" ] && [ "$(stat -c%s "$out")" -gt $((10*1024*1024)) ]; then
      log "${GREEN}✓ Success${NC}"
      ((success_count++))
    else
      log "${RED}✗ File too small or empty (download likely failed).${NC}"
      ((fail_count++))
      return 1
    fi
  else
    code=$?
    case "$code" in
      22) log "${RED}✗ HTTP error (401/403/404). Check token or URL.${NC}" ;;
      28) log "${RED}✗ Timeout. Network slow; try again.${NC}" ;;
      56) log "${RED}✗ Connection aborted mid-transfer.${NC}" ;;
      *)  log "${RED}✗ curl failed (exit ${code}).${NC}" ;;
    esac
    ((fail_count++))
    return 1
  fi
}

# ===================== downloads ==========================
log "=== Downloading CHECKPOINTS ==="
gather_urls "CHECKPOINT" | while IFS= read -r u; do
  download_to_dir "$u" "$CHECKPOINT_DIR" "safetensors"
done || true

log "=== Downloading LORAS ==="
gather_urls "LORA" | while IFS= read -r u; do
  download_to_dir "$u" "$LORA_DIR" "safetensors"
done || true

log "=== Downloading VAEs ==="
gather_urls "VAE" | while IFS= read -r u; do
  download_to_dir "$u" "$VAE_DIR" "safetensors"
done || true

# ===================== summary ============================
echo
if (( fail_count > 0 )); then
  log "⚠️  Download summary: ${GREEN}${success_count} OK${NC}, ${RED}${fail_count} failed${NC}"
  exit 1
else
  log "${GREEN}✓ All downloads complete (${success_count})${NC}"
fi

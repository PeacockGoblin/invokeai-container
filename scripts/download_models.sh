#!/usr/bin/env bash
set -euo pipefail

: "${INVOKEAI_ROOT:?INVOKEAI_ROOT must be set}"
: "${CIVITAI_TOKEN:-}"

CHECKPOINT_DIR="${INVOKEAI_ROOT}/models/checkpoints"
LORA_DIR="${INVOKEAI_ROOT}/models/loras"
VAE_DIR="${INVOKEAI_ROOT}/models/vae"

mkdir -p "$CHECKPOINT_DIR" "$LORA_DIR" "$VAE_DIR"

log() { printf '%s\n' "$*" >&2; }

# --- Normalize URL lists ---
# Accepts comma- or newline-separated lists and trims whitespace.
split_list() {
  # usage: split_list "raw" -> prints one URL per line
  local raw="${1:-}"
  # convert commas to newlines, trim spaces, drop empties
  printf '%s' "$raw" \
    | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' \
    | awk 'NF'
}

# Gather values from numbered env vars like LORA_URL_1, LORA_URL_2, ...
collect_numbered() {
  # usage: collect_numbered "PREFIX_" -> echoes values, one per line
  local prefix="$1"
  # env might not preserve order; sort by numeric suffix
  env | grep -E "^${prefix}[0-9]+=" | sort -t'_' -k3,3n | while IFS='=' read -r k v; do
    # strip key= and leave value (handles values with '=' by using POSIX split)
    printf '%s\n' "${v}"
  done
}

# De-duplicate while preserving order
uniq_stable() {
  awk '!seen[$0]++'
}

# Merge all sources for a given type into a unique list
gather_urls() {
  # usage: gather_urls "CHECKPOINT" prints URLs for that type
  local kind="$1" upper lower single list prefix
  upper="$kind"                             # e.g., CHECKPOINT
  lower="$(printf '%s' "$kind" | tr 'A-Z' 'a-z')"  # checkpoint

  single="${upper}_URL"                     # CHECKPOINT_URL
  list="${upper}_URLS"                      # CHECKPOINT_URLS
  prefix="${upper}_URL_"                    # CHECKPOINT_URL_

  {
    # single value
    [ -n "${!single-}" ] && printf '%s\n' "${!single}"
    # list (comma or newline separated)
    [ -n "${!list-}" ] && split_list "${!list}"
    # numbered
    collect_numbered "${prefix}"
  } | uniq_stable
}

# Robust curl downloader:
# - follows redirects (-L)
# - resumes partial (-C -)
# - honors Content-Disposition filename (-J -O)
# - retries a few times
# - writes into dest dir without clobbering existing files unnecessarily
download_to_dir() {
  local url="$1" dest_dir="$2"
  [ -z "${url:-}" ] && return 0

  log "→ Download: $url"
  if [ -n "${CIVITAI_TOKEN:-}" ]; then
    curl -fL -C - \
      -H "Authorization: Bearer ${CIVITAI_TOKEN}" \
      -H "Accept: application/octet-stream" \
      -J -O --retry 5 --retry-delay 2 \
      --output-dir "$dest_dir" \
      "$url"
  else
    curl -fL -C - -J -O --retry 5 --retry-delay 2 \
      --output-dir "$dest_dir" \
      "$url"
  fi
}

# Optionally skip if a same-name file is already present (best-effort).
# Because we rely on server-provided names (-J), simply attempting the
# download with -C - is safe and fast (no-op if complete).

# === CHECKPOINTS ===
gather_urls "CHECKPOINT" | while IFS= read -r u; do
  download_to_dir "$u" "$CHECKPOINT_DIR"
done

# === LORAS ===
gather_urls "LORA" | while IFS= read -r u; do
  download_to_dir "$u" "$LORA_DIR"
done

# === VAE ===
gather_urls "VAE" | while IFS= read -r u; do
  download_to_dir "$u" "$VAE_DIR"
done

log "✓ Downloads complete (or skipped where already present)"

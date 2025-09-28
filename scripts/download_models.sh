#!/usr/bin/env bash
set -euo pipefail

: "${INVOKEAI_ROOT:?INVOKEAI_ROOT must be set}"
MODELS_DIR="${INVOKEAI_ROOT}/models"
CHECKPOINT_DIR="${MODELS_DIR}/checkpoints"
LORA_DIR="${MODELS_DIR}/loras"
VAE_DIR="${MODELS_DIR}/vae"

mkdir -p "$CHECKPOINT_DIR" "$LORA_DIR" "$VAE_DIR"

dl() {
  local url="$1"
  local outdir="$2"
  [[ -z "${url}" ]] && return 0
  if [[ -n "${CIVITAI_TOKEN:-}" ]]; then
    if [[ "$url" == *"?"* ]]; then
      url="${url}&token=${CIVITAI_TOKEN}"
    else
      url="${url}?token=${CIVITAI_TOKEN}"
    fi
  fi
  echo "➡️  Downloading: $url -> $outdir"
  (cd "$outdir" && wget -q --show-progress --content-disposition -L "$url")
}

dl "${CHECKPOINT_URL:-}" "$CHECKPOINT_DIR"
dl "${LORA_URL_1:-}" "$LORA_DIR"
dl "${LORA_URL_2:-}" "$LORA_DIR"
dl "${LORA_URL_3:-}" "$LORA_DIR"
dl "${VAE_URL:-}" "$VAE_DIR"

echo "✅ Downloads saved (if any) to:"
echo "   - $CHECKPOINT_DIR"
echo "   - $LORA_DIR"
echo "   - $VAE_DIR"

# For any unregistered items, use 'Manage Models' -> 'Scan Folder' in the UI.

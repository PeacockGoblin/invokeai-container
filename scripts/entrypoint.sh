#!/usr/bin/env bash
set -euo pipefail

: "${INVOKEAI_ROOT:?INVOKEAI_ROOT must be set}"
: "${GPU_DRIVER:=cuda}"
: "${INVOKE_PORT:=9090}"

echo "== InvokeAI bootstrap =="
echo "INVOKEAI_ROOT: $INVOKEAI_ROOT"
echo "GPU_DRIVER:    $GPU_DRIVER"
echo "INVOKE_PORT:   $INVOKE_PORT"

mkdir -p "$INVOKEAI_ROOT"
chown -R "$(id -u)":"$(id -g)" "$INVOKEAI_ROOT" || true

# Model/LoRA/VAE downloads (non-fatal if a URL is bad)
if ! bash /opt/invoke-bootstrap/download_models.sh; then
  echo "⚠️  Model download step had a warning; continuing."
fi

echo "Starting InvokeAI Web UI on 0.0.0.0:${INVOKE_PORT}..."
exec invokeai-web --host 0.0.0.0 --port "${INVOKE_PORT}"

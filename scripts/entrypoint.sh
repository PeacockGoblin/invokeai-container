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
chown -R "$(id -u):$(id -g)" "$INVOKEAI_ROOT" || true

# --- Download models ---
if ! bash /opt/invoke-bootstrap/download_models.sh; then
  echo "⚠️  Model download step had a warning; continuing."
fi

# --- Launch InvokeAI ---
echo "Starting InvokeAI Web UI..."

# Newer versions ignore --host/--port; rely on envs instead
export INVOKEAI_WEB_HOST=0.0.0.0
export INVOKEAI_WEB_PORT="${INVOKE_PORT}"

# Use exec to hand off control
exec invokeai-web

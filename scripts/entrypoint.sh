#!/usr/bin/env bash
set -euo pipefail

: "${INVOKEAI_ROOT:?INVOKEAI_ROOT must be set}"
: "${GPU_DRIVER:=cuda}"

echo "== InvokeAI bootstrap =="
echo "INVOKEAI_ROOT: $INVOKEAI_ROOT"
echo "GPU_DRIVER:    $GPU_DRIVER"

mkdir -p "$INVOKEAI_ROOT"
chown -R $(id -u):$(id -g) "$INVOKEAI_ROOT" || true

bash /opt/invoke-bootstrap/download_models.sh || {
  echo "⚠️  Model download step had a warning; continuing."
}

echo "Starting InvokeAI Web UI on port 9090..."
exec invokeai-web

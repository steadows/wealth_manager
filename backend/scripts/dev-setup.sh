#!/usr/bin/env bash
# One-command local dev startup: install deps, run migrations, start server.
# Usage: ./scripts/dev-setup.sh [port]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
PORT="${1:-8000}"
CONDA_ENV="wealth-manager"
PYTHON="/opt/anaconda3/envs/${CONDA_ENV}/bin/python"

cd "$BACKEND_DIR"
export PYTHONPATH="$BACKEND_DIR"

echo "=== Installing dependencies ==="
conda run -n "$CONDA_ENV" pip install -q -r requirements.txt

echo "=== Running database migrations ==="
conda run -n "$CONDA_ENV" env PYTHONPATH="$BACKEND_DIR" alembic upgrade head

echo "=== Starting server on port ${PORT} ==="
exec "$PYTHON" -m uvicorn app.main:app --host 127.0.0.1 --port "$PORT"

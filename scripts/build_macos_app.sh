#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 -m pip install -r requirements.txt
python3 -m pip install -r requirements-desktop.txt
python3 -m PyInstaller --noconfirm desktop/pediatrics_rag.spec

echo "Built app bundle: $ROOT_DIR/dist/PediatricsRAG.app"

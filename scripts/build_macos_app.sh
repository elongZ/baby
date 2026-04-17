#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 -m pip install -r requirements/base.txt
python3 -m pip install -r requirements/desktop.txt
python3 -m PyInstaller \
  --noconfirm \
  --distpath workspace/dist \
  --workpath workspace/tmp/pyinstaller \
  apps/mac/desktop/pediatrics_rag.spec

echo "Built app bundle: $ROOT_DIR/workspace/dist/PediatricsRAG.app"

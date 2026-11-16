#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# The team renamed the default branch master -> main: the repo only has `main`.
am_repo_seed invoices "$LEVEL_DIR/repo" "invoices v3.1 manifests"
kubectl create namespace invoices >/dev/null

am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh invoices
am_wait_app invoices cond=ComparisonError --timeout 120 || { echo "setup: no ComparisonError appeared"; exit 1; }
am_workspace_clone invoices

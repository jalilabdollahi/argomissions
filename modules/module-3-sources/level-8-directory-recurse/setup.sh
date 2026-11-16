#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed inventory-stack "$LEVEL_DIR/repo" "inventory stack: web and db manifests"
kubectl create namespace inventory >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh inventory
am_wait_app inventory sync=Synced --timeout 90 || { echo "setup: app did not settle"; exit 1; }
am_workspace_clone inventory-stack

am_setup_assert "nothing deployed in inventory" bash -c '[ -z "$(kubectl -n inventory get deploy -o name)" ]'

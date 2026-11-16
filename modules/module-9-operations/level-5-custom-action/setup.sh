#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed ferry-booking "$LEVEL_DIR/repo" "ferry-booking v5.0 manifests"
kubectl create namespace ferry >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh ferry-booking
am_wait_app ferry-booking sync=Synced health=Healthy --timeout 150 || { echo "setup: first sync did not settle"; exit 1; }
am_workspace_clone ferry-booking

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed docs-portal "$LEVEL_DIR/repo" "docs-portal manifests"
kubectl create namespace docs >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh docs-portal
am_wait_app docs-portal sync=Synced --timeout 90 || { echo "setup: app did not settle"; exit 1; }
am_workspace_clone docs-portal

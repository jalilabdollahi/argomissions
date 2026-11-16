#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed billing "$LEVEL_DIR/repo" "billing v3.1 manifests"
kubectl create namespace billing >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh billing
am_wait_app billing sync=OutOfSync --timeout 60 || { echo "setup: app did not appear"; exit 1; }
# The release manager's first sync attempt.
am_app_sync_now billing
am_wait_app billing op=Failed --timeout 120 || { echo "setup: sync did not fail"; exit 1; }
am_workspace_clone billing

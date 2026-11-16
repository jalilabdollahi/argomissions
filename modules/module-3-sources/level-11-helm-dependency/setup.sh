#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed notify-platform "$LEVEL_DIR/repo" "notify chart with notify-common library dependency"
kubectl create namespace notifications >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh notify
am_wait_app notify cond=ComparisonError --timeout 90 || { echo "setup: no comparison error"; exit 1; }
am_workspace_clone notify-platform

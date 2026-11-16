#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed telemetry "$LEVEL_DIR/repo" "telemetry v1.7 manifests"
kubectl create namespace telemetry >/dev/null

am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh telemetry
am_wait_app telemetry cond="InvalidSpecError" --timeout 120 || { echo "setup: no InvalidSpecError appeared"; exit 1; }
am_workspace_clone telemetry

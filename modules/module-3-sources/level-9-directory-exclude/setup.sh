#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed telemetry-agents "$LEVEL_DIR/repo" "collector manifests and CI fixtures"
kubectl create namespace telemetry >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh collector
am_wait_app collector sync=Synced health=Healthy --timeout 150 || { echo "setup: collector did not become healthy"; exit 1; }
am_workspace_clone telemetry-agents

am_setup_assert "fixture pods run in telemetry" bash -c '[ "$(kubectl -n telemetry get pods -l app=fixture-loadgen -o name | wc -l)" -ge 1 ]'

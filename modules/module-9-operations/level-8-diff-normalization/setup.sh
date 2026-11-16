#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# The StatusBoard CRD belongs to the platform, not to the app: installed directly, removed by the engine reset.
kubectl apply -f "$LEVEL_DIR/assets/crd.yaml" >/dev/null
kubectl wait --for=condition=Established crd/statusboards.argomissions.io --timeout=60s >/dev/null

am_repo_seed statusboard-config "$LEVEL_DIR/repo" "On-call StatusBoard"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh ops-statusboard
am_wait_app ops-statusboard sync=OutOfSync --timeout 120 || { echo "setup: ops-statusboard never became OutOfSync"; exit 1; }
am_app_sync_now ops-statusboard
am_wait_app ops-statusboard op=Succeeded --timeout 120 || { echo "setup: the first sync did not succeed"; exit 1; }
am_app_refresh ops-statusboard
persistent_diff() { [ "$(am_app_sync ops-statusboard)" = OutOfSync ]; }
am_setup_assert "the app stays OutOfSync right after a successful sync" am_wait 60 persistent_diff
am_workspace_clone statusboard-config

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed shipping-ui "$LEVEL_DIR/repo" "shipping-ui manifests"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh shipping-ui
am_wait_app shipping-ui sync=OutOfSync --timeout 120 || { echo "setup: shipping-ui never became OutOfSync"; exit 1; }
am_app_sync_now shipping-ui
am_wait_app shipping-ui op=Running opmsg="waiting for healthy state of apps/Deployment/shipping-ui" --timeout 150 || { echo "setup: the first sync is not waiting on the Deployment"; exit 1; }
am_setup_assert "pod stuck on the missing ConfigMap" bash -c "kubectl -n shipping get pods -o json | jq -e '[.items[].status.containerStatuses[]?.state.waiting.reason] | index(\"CreateContainerConfigError\")'"
am_workspace_clone shipping-ui

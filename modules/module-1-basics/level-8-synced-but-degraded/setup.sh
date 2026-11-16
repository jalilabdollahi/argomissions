#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed notifier "$LEVEL_DIR/repo" "notifier v2.0 manifests"
kubectl create namespace messaging >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh notifier
am_wait_app notifier sync=OutOfSync --timeout 60 || { echo "setup: app did not appear"; exit 1; }
# The release manager's sync: it succeeds, the pod can never start, the Deployment misses its progress deadline.
am_app_sync_now notifier
am_wait_app notifier sync=Synced op=Succeeded --timeout 120 || { echo "setup: sync did not succeed"; exit 1; }
am_wait_app notifier sync=Synced health=Degraded --timeout 150 || { echo "setup: app did not turn Degraded"; exit 1; }
am_workspace_clone notifier

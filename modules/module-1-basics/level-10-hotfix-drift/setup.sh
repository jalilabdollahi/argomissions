#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed checkout "$LEVEL_DIR/repo" "checkout v5.2 manifests"
kubectl create namespace checkout >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh checkout
am_wait_app checkout sync=OutOfSync --timeout 60 || { echo "setup: app did not appear"; exit 1; }
am_app_sync_now checkout
am_wait_app checkout sync=Synced health=Healthy --timeout 120 || { echo "setup: first sync did not settle"; exit 1; }
# On-call during the load spike: scaled by hand, never written down in Git.
kubectl -n checkout scale deploy/checkout --replicas=3 >/dev/null
am_wait_app checkout sync=OutOfSync --timeout 90 || { echo "setup: drift not detected"; exit 1; }
three_ready() { [ "$(am_ready_replicas checkout checkout)" = 3 ]; }
am_wait 90 three_ready || { echo "setup: 3 pods not ready"; exit 1; }
am_workspace_clone checkout

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed reports "$LEVEL_DIR/repo" "report-worker v1.0"
kubectl create namespace reports >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh reports
am_wait_app reports sync=OutOfSync --timeout 60 || { echo "setup: app did not appear"; exit 1; }
am_app_sync_now reports
am_wait_app reports sync=Synced health=Healthy op=Succeeded --timeout 120 || { echo "setup: first sync did not settle"; exit 1; }

# A colleague "tunes the worker flags"; the release is synced and the worker crash-loops.
am_repo_commit reports "$LEVEL_DIR/assets/tuned" "tune worker flags"
am_app_refresh reports
am_wait_app reports rev="$(am_repo_head reports)" --timeout 60 || { echo "setup: new commit not seen"; exit 1; }
am_app_sync_now reports
am_wait_app reports sync=Synced health=Degraded op=Succeeded --timeout 150 || { echo "setup: app did not turn Degraded"; exit 1; }
am_workspace_clone reports

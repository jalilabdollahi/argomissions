#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed mail-relay "$LEVEL_DIR/repo" "mail-relay v3.2 manifests"
kubectl create namespace mailroom >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/project.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh mail-relay
am_wait_app mail-relay sync=OutOfSync --timeout 90 || { echo "setup: app did not compare"; exit 1; }

am_app_sync_now mail-relay
am_wait_app mail-relay op=Failed opmsg="is not permitted in project" --timeout 90 \
  || { echo "setup: the sync did not fail on the project policy"; exit 1; }
am_setup_assert "nothing deployed" bash -c '! kubectl -n mailroom get deploy mail-relay'
am_workspace_clone mail-relay

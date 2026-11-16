#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed radar-agent "$LEVEL_DIR/repo" "radar-agent v0.9 manifests"
kubectl create namespace radar >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/project.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh radar-agent
am_wait_app radar-agent sync=OutOfSync --timeout 90 || { echo "setup: app did not compare"; exit 1; }

# the team presses Sync, as they did this morning
am_app_sync_now radar-agent
am_wait_app radar-agent op=Failed opmsg="is not permitted in project" --timeout 90 \
  || { echo "setup: the sync did not fail on the project policy"; exit 1; }
am_setup_assert "nothing deployed" bash -c '! kubectl -n radar get deploy radar-agent'

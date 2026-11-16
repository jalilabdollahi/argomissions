#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed metrics-gw "$LEVEL_DIR/repo" "metrics-gw v1.0 manifests"
kubectl create namespace metrics >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh metrics-gw
am_wait_app metrics-gw sync=OutOfSync --timeout 60 || { echo "setup: app did not appear"; exit 1; }
am_app_sync_now metrics-gw
am_wait_app metrics-gw sync=Synced health=Healthy --timeout 120 || { echo "setup: first sync did not settle"; exit 1; }

# Three releases land on main while the Application is still manual.
for v in 1.1 1.2 1.3; do
  rm -rf "$AM_TMP/rel"; mkdir -p "$AM_TMP/rel/deploy"
  sed "s/metrics-gw v1.0/metrics-gw v$v/" "$LEVEL_DIR/repo/deploy/deployment.yaml" >"$AM_TMP/rel/deploy/deployment.yaml"
  am_repo_commit metrics-gw "$AM_TMP/rel" "Release metrics-gw v$v"
done
am_app_refresh metrics-gw
am_wait_app metrics-gw sync=OutOfSync --timeout 90 || { echo "setup: app did not notice the new commits"; exit 1; }
am_setup_assert "syncPolicy is manual" bash -c '[ -z "$(kubectl -n argocd get application metrics-gw -o jsonpath="{.spec.syncPolicy.automated}")" ]'
am_workspace_clone metrics-gw

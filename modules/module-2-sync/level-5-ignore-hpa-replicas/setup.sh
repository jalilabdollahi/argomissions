#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed quote-api "$LEVEL_DIR/repo" "quote-api v5.0 manifests"
kubectl create namespace quotes >/dev/null
kubectl create namespace quotes-scaler >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh quote-api
am_wait_app quote-api sync=Synced health=Healthy --timeout 150 || { echo "setup: first sync did not settle"; exit 1; }

# Traffic arrives: the platform's autoscaler starts doing its job.
kubectl apply -f "$LEVEL_DIR/assets/load-scaler.yaml" >/dev/null
kubectl -n quotes-scaler rollout status deploy/load-scaler --timeout=90s >/dev/null
am_setup_assert "the fight is on (Deployment spec rewritten at least 4 times)" \
  am_wait 120 bash -c '[ "$(kubectl -n quotes get deploy quote-api -o jsonpath="{.metadata.generation}")" -ge 5 ]'
am_workspace_clone quote-api

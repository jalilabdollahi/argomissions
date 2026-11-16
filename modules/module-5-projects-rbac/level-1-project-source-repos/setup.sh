#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed intake-gateway "$LEVEL_DIR/repo" "claims-intake v2.3 manifests"
kubectl create namespace claims >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/project.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh claims-intake

am_wait_app claims-intake cond="is not permitted in project" --timeout 90 \
  || { echo "setup: the repo-not-permitted condition did not appear"; exit 1; }
am_setup_assert "nothing deployed yet" bash -c '! kubectl -n claims get deploy claims-intake'

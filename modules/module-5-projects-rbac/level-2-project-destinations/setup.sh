#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed rx-dispatch "$LEVEL_DIR/repo" "rx-dispatch v4.1 manifests"
kubectl create namespace pharmacy >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/project.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh rx-dispatch

am_wait_app rx-dispatch cond="do not match any of the allowed destinations" --timeout 90 \
  || { echo "setup: the destination-not-permitted condition did not appear"; exit 1; }
am_setup_assert "nothing deployed yet" bash -c '! kubectl -n pharmacy get deploy rx-dispatch'

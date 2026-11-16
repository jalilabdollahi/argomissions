#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed media-store "$LEVEL_DIR/repo" "media-store v1.4 manifests"
kubectl create namespace media >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh media-store
am_wait_app media-store sync=Synced health=Healthy --timeout 180 || { echo "setup: first sync did not settle"; exit 1; }
am_setup_assert "PVC bound" am_wait 60 test "$(kubectl -n media get pvc uploads -o jsonpath='{.status.phase}')" = Bound
am_setup_assert "seed file written" am_wait 30 kubectl -n media logs deploy/media-store -c seed
# The storage team's audit note: the identity of the claim that holds the customers' uploads.
uid="$(kubectl -n media get pvc uploads -o jsonpath='{.metadata.uid}')"
kubectl -n media create configmap storage-audit --from-literal=uploads-pvc-uid="$uid" >/dev/null
am_workspace_clone media-store

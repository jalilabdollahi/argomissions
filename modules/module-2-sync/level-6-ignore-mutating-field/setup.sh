#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed profile-svc "$LEVEL_DIR/repo" "profile-svc v2.3 manifests"
kubectl create namespace profiles >/dev/null
kubectl create namespace profiles-finops >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh profile-svc
am_wait_app profile-svc sync=Synced health=Healthy --timeout 150 || { echo "setup: first sync did not settle"; exit 1; }

# The finance platform's controller goes live and starts stamping the Deployment.
kubectl apply -f "$LEVEL_DIR/assets/cost-stamper.yaml" >/dev/null
kubectl -n profiles-finops rollout status deploy/cost-stamper --timeout=90s >/dev/null
am_wait_app profile-svc sync=OutOfSync --timeout 120 || { echo "setup: the mutation was not detected"; exit 1; }
sleep 25   # automated sync (no self-heal) must leave it alone, and the stamper must have written again
am_setup_assert "still OutOfSync" bash -c '[ "$(kubectl -n argocd get application profile-svc -o jsonpath="{.status.sync.status}")" = OutOfSync ]'
am_workspace_clone profile-svc

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

SVCS="ingest rollup gateway"
am_repo_seed tallyline "$LEVEL_DIR/repo" "tallyline v4.2 manifests"
for s in $SVCS; do kubectl create namespace "tallyline-$s" >/dev/null; done
kubectl create namespace complyd-system >/dev/null
am_app_apply "$LEVEL_DIR/assets/apps.yaml"
for s in $SVCS; do am_app_refresh "tallyline-$s"; done
for s in $SVCS; do
  am_wait_app "tallyline-$s" sync=Synced health=Healthy --timeout 150 || { echo "setup: first sync of tallyline-$s did not settle"; exit 1; }
done

# The security team's compliance scanner goes live and starts stamping every Deployment.
kubectl apply -f "$LEVEL_DIR/assets/complyd.yaml" >/dev/null
kubectl -n complyd-system rollout status deploy/complyd --timeout=90s >/dev/null
for s in $SVCS; do
  am_wait_app "tallyline-$s" sync=OutOfSync --timeout 120 || { echo "setup: the mutation of tallyline-$s was not detected"; exit 1; }
done
sleep 20   # automated sync (no self-heal) must leave them alone
for s in $SVCS; do
  am_setup_assert "tallyline-$s still OutOfSync" bash -c "[ \"\$(kubectl -n argocd get application tallyline-$s -o jsonpath='{.status.sync.status}')\" = OutOfSync ]"
done
am_workspace_clone tallyline

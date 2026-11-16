#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed inventory-gitops "$LEVEL_DIR/repo" "inventory-gitops: stock-api and stock-sync"
am_app_apply "$LEVEL_DIR/assets/root.yaml"
am_app_refresh inventory-root
for c in stock-api stock-sync; do
  am_wait_app "$c" sync=Synced health=Healthy --timeout 150 || { echo "setup: $c did not become Healthy"; exit 1; }
done
am_wait_app inventory-root sync=Synced --timeout 60
# Remember the UID of the untouched service: a clean recovery must not restart it.
kubectl -n inventory-sync create configmap recovery-baseline \
  --from-literal=stock-sync-uid="$(kubectl -n inventory-sync get deploy stock-sync -o jsonpath='{.metadata.uid}')" >/dev/null

# The accident: a tidy-up commit deletes a manifest that is very much in use.
DELETE="apps/api.yaml" am_repo_commit inventory-gitops "" "cleanup: drop unused manifests"
am_app_refresh inventory-root
am_wait 120 bash -c '! kubectl -n argocd get application stock-api' || { echo "setup: stock-api Application still exists"; exit 1; }
am_wait 120 bash -c '! kubectl -n inventory-stock get deploy stock-api' || { echo "setup: stock-api workload still exists"; exit 1; }
am_wait_app inventory-root sync=Synced --timeout 60
am_workspace_clone inventory-gitops

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed stockroom-db "$LEVEL_DIR/repo" "stockroom-db: plain manifests and the new chart"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh stockroom-db-v2
am_wait_app stockroom-db-v2 sync=Synced health=Healthy --timeout 180 || { echo "setup: the plain-manifest deploy did not settle"; exit 1; }
am_setup_assert "PVC bound" am_wait 90 test "$(kubectl -n stockroom get pvc stockroom-db-data -o jsonpath='{.status.phase}')" = Bound

# a year of inventory data on the volume
kubectl -n stockroom exec deploy/stockroom-db -- sh -c 'echo "seq=4821 shipments=1873" > /data/seq'
uid="$(kubectl -n stockroom get pvc stockroom-db-data -o jsonpath='{.metadata.uid}')"
kubectl -n argocd delete configmap argomissions-stockroom-baseline --ignore-not-found >/dev/null
kubectl -n argocd create configmap argomissions-stockroom-baseline --from-literal=pvc-uid="$uid" >/dev/null
kubectl -n argocd label configmap argomissions-stockroom-baseline argomissions.io/cleanup=true >/dev/null
body="$(am_http http://stockroom-db.stockroom/seq stockroom 8)" || { echo "setup: stockroom-db does not answer"; exit 1; }
[ "$body" = "seq=4821 shipments=1873" ] || { echo "setup: unexpected data '$body'"; exit 1; }

# The migration PR: the Application now reads the chart, with a values file, an old incident parameter, and manual sync.
kubectl -n argocd patch application stockroom-db-v2 --type merge --patch-file "$LEVEL_DIR/assets/migration-patch.yaml" >/dev/null
am_app_refresh stockroom-db-v2
am_wait_app stockroom-db-v2 cond="values/prod.yaml" --timeout 120 || { echo "setup: no ComparisonError for the values file"; exit 1; }
am_workspace_clone stockroom-db

#!/bin/bash
# Wrong: a global customization that ignores the whole metadata of every Deployment.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$LEVEL_DIR/assets/ignore-scan-label.yaml"
kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"resource.customizations.ignoreDifferences.apps_Deployment":"jsonPointers:\n- /metadata\n- /spec\n"}}'
for s in ingest rollup gateway; do am_app_refresh "tallyline-$s" normal; done
for s in ingest rollup gateway; do am_wait_app "tallyline-$s" sync=Synced health=Healthy --timeout 120; done

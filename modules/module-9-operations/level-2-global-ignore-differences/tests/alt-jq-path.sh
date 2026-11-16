#!/bin/bash
# Correct too: the same global customization written as a jq path expression.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge --patch-file /dev/stdin <<'YAML'
data:
  resource.customizations.ignoreDifferences.apps_Deployment: |
    jqPathExpressions:
    - '.metadata.labels."complyd.argomissions.io/scan"'
YAML
for s in ingest rollup gateway; do am_app_refresh "tallyline-$s" normal; done
for s in ingest rollup gateway; do am_wait_app "tallyline-$s" sync=Synced health=Healthy --timeout 120; done

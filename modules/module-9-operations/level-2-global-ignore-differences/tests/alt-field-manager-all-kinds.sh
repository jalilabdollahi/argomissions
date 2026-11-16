#!/bin/bash
# Correct too: ignore whatever the scanner's field manager writes, for every kind (the `all` customization).
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge --patch-file /dev/stdin <<'YAML'
data:
  resource.customizations.ignoreDifferences.all: |
    managedFieldsManagers:
    - complyd
YAML
for s in ingest rollup gateway; do am_app_refresh "tallyline-$s" normal; done
for s in ingest rollup gateway; do am_wait_app "tallyline-$s" sync=Synced health=Healthy --timeout 120; done

#!/bin/bash
# Wrong: undo the restructure by copying the manifests back to k8s/ (the Application then "works").
set -euo pipefail
source "$AM_LIB"

mkdir -p "$SANDBOX/catalog/k8s"
cp "$SANDBOX"/catalog/deploy/catalog/*.yaml "$SANDBOX/catalog/k8s/"
am_player_push "$SANDBOX/catalog" "copy manifests back to k8s"
am_app_refresh catalog
am_argocd app sync catalog --timeout 120
am_wait_app catalog sync=Synced health=Healthy --timeout 120

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# The team's label is `deploy-preview`; the ApplicationSet filters on `preview`.
sed -i.bak 's/^\(        - \)preview$/\1deploy-preview/' "$SANDBOX/pulse-previews-appset.yaml"
rm -f "$SANDBOX/pulse-previews-appset.yaml.bak"
kubectl apply -f "$SANDBOX/pulse-previews-appset.yaml"
app_up() { [ "$(kubectl -n argocd get applications -o name | wc -l | tr -d ' ')" = 1 ]; }
am_wait 90 app_up
app="$(kubectl -n argocd get applications -o jsonpath='{.items[0].metadata.name}')"
am_wait_app "$app" sync=Synced health=Healthy --timeout 150

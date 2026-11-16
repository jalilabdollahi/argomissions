#!/bin/bash
# Correct too: the label corrected with a JSON patch on the live ApplicationSet.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset pulse-previews --type json \
  -p '[{"op":"replace","path":"/spec/generators/0/pullRequest/gitea/labels/0","value":"deploy-preview"}]'
app_up() { [ "$(kubectl -n argocd get applications -o name | wc -l | tr -d ' ')" = 1 ]; }
am_wait 90 app_up
app="$(kubectl -n argocd get applications -o jsonpath='{.items[0].metadata.name}')"
am_wait_app "$app" sync=Synced health=Healthy --timeout 150

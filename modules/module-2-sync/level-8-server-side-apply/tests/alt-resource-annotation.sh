#!/bin/bash
# Correct too: only the oversized ConfigMap opts into server-side apply, through an annotation in Git.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/host-registry"
sed -i.bak 's#^  name: host-inventory$#  name: host-inventory\n  annotations:\n    argocd.argoproj.io/sync-options: ServerSideApply=true#' deploy/host-inventory.yaml
rm -f deploy/host-inventory.yaml.bak
am_player_push . "host-inventory: apply server-side"
am_app_refresh host-registry
am_wait_app host-registry sync=OutOfSync --timeout 60
am_argocd app sync host-registry --timeout 120
am_wait_app host-registry sync=Synced health=Healthy --timeout 120

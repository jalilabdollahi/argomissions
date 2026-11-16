#!/bin/bash
# Wrong: turn the folder into a real chart (manifests into templates/). It deploys, but through Helm: the
# plain-manifest repo the team wants is gone.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/docs-portal/deploy"
mkdir templates
git mv deployment.yaml service.yaml templates/
am_player_push "$SANDBOX/docs-portal" "convert deploy/ into a chart"
am_argocd app get docs-portal --refresh >/dev/null
am_wait_app docs-portal sync=Synced health=Healthy --timeout 150

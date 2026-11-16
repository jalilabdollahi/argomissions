#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/docs-portal"
git rm -q deploy/Chart.yaml deploy/values.yaml
am_player_push "$SANDBOX/docs-portal" "remove leftover Helm files"
am_argocd app get docs-portal --refresh >/dev/null
am_wait_app docs-portal sync=Synced health=Healthy --timeout 150

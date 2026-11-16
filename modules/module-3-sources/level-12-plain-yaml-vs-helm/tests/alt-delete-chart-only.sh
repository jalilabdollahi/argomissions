#!/bin/bash
# Also correct: only Chart.yaml is removed, values.yaml stays (it is not a Kubernetes object, Argo CD ignores it).
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/docs-portal"
git rm -q deploy/Chart.yaml
am_player_push "$SANDBOX/docs-portal" "remove Chart.yaml"
am_argocd app get docs-portal --refresh >/dev/null
am_wait_app docs-portal sync=Synced health=Healthy --timeout 150

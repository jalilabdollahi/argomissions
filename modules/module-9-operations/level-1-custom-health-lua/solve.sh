#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$LEVEL_DIR/assets/health-lua.yaml"
am_app_refresh vaultline normal
degraded_seen() { am_argocd app get vaultline -o json | jq -e '[.status.resources[] | select(.health.status == "Degraded")] | length == 1'; }
am_wait 60 degraded_seen

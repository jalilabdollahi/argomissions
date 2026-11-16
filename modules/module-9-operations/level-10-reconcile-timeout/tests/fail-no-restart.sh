#!/bin/bash
# Wrong: argocd-cm is fixed and the app refreshed, but no component was restarted: they keep 24h.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"timeout.reconciliation":"60s"}}'
am_app_refresh lobby-board
head="$(am_repo_head lobby-board)"
am_wait_app lobby-board sync=Synced health=Healthy op=Succeeded oprev="$head" --timeout 150

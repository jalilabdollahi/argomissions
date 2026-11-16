#!/bin/bash
# Wrong: only the application controller is restarted; the repo-server keeps caching branch lookups for 24h.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"timeout.reconciliation":"60s"}}'
kubectl -n argocd rollout restart statefulset/argocd-application-controller
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=180s
am_app_refresh lobby-board
head="$(am_repo_head lobby-board)"
am_wait_app lobby-board sync=Synced health=Healthy op=Succeeded oprev="$head" --timeout 150

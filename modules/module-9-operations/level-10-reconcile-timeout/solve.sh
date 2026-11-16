#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"timeout.reconciliation":"180s"}}'
# The value reaches the components as an environment variable: only a restart makes them read it.
kubectl -n argocd rollout restart statefulset/argocd-application-controller deploy/argocd-repo-server
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=180s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=180s
am_app_refresh lobby-board
head="$(am_repo_head lobby-board)"
am_wait_app lobby-board sync=Synced health=Healthy op=Succeeded oprev="$head" --timeout 180

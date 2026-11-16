#!/bin/bash
# Correct too: 60s (the value the rest of the game uses), applied by deleting the pods instead of a rollout.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"timeout.reconciliation":"60s"}}'
kubectl -n argocd delete pod argocd-application-controller-0 --wait=true >/dev/null
kubectl -n argocd delete pod -l app.kubernetes.io/name=argocd-repo-server --wait=true >/dev/null
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=180s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=180s
am_app_refresh lobby-board
head="$(am_repo_head lobby-board)"
am_wait_app lobby-board sync=Synced health=Healthy op=Succeeded oprev="$head" --timeout 180

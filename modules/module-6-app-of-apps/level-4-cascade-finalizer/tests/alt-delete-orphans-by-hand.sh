#!/bin/bash
# Correct too: finalizer added to the remaining child in Git; the orphaned workload removed directly.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/tariff-gitops"
sed -i.bak 's/^  namespace: argocd/  namespace: argocd\n  finalizers:\n  - resources-finalizer.argocd.argoproj.io/' apps/api.yaml && rm apps/api.yaml.bak
am_player_push . "tariff-api: resources-finalizer"
head="$(am_repo_head tariff-gitops)"
am_app_refresh tariff-root
am_wait_app tariff-root rev="$head" sync=Synced --timeout 120
kubectl delete namespace tariff-old --wait=true
am_app_refresh tariff-api
am_wait_app tariff-api rev="$head" sync=Synced health=Healthy --timeout 120

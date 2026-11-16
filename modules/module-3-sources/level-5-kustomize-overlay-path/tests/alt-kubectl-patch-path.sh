#!/bin/bash
# Correct too: change the path declaratively.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application inventory-sync --type merge -p '{"spec":{"source":{"path":"kustomize/overlays/prod/"}}}'
am_app_refresh inventory-sync
am_argocd app sync inventory-sync --timeout 120
am_wait_app inventory-sync sync=Synced health=Healthy --timeout 120
kubectl -n inventory rollout status deploy/inventory-sync --timeout=90s

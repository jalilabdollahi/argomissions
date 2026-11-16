#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set inventory-sync --path kustomize/overlays/prod
am_argocd app sync inventory-sync --timeout 120
am_argocd app wait inventory-sync --health --timeout 120
kubectl -n inventory rollout status deploy/inventory-sync --timeout=90s

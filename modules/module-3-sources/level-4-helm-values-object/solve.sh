#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# The values must sit directly under valuesObject (no chart-name wrapper): replace the whole object.
kubectl -n argocd patch application search-suggest --type json -p '[{"op":"replace","path":"/spec/source/helm/valuesObject","value":{"replicaCount":3,"banner":"search-suggest prod 4.1"}}]'
am_app_refresh search-suggest
am_argocd app sync search-suggest --timeout 120
am_argocd app wait search-suggest --health --timeout 120
kubectl -n search rollout status deploy/search-suggest --timeout=90s

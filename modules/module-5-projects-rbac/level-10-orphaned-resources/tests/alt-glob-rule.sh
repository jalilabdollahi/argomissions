#!/bin/bash
# Correct too: a glob rule for the manually issued certificates (`search-tls-*`), cleanup selected by label.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject search-platform --type merge \
  -p '{"spec":{"orphanedResources":{"warn":true,"ignore":[{"kind":"Secret","name":"search-tls-*"}]}}}'
am_app_refresh query-service hard
am_wait 40 bash -c "kubectl -n argocd get app query-service -o json | grep -q OrphanedResourceWarning"
kubectl -n search delete deployment -l app=legacy-indexer
am_app_refresh query-service hard

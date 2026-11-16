#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject search-platform --type merge \
  -p '{"spec":{"orphanedResources":{"warn":true,"ignore":[{"group":"","kind":"Secret","name":"search-tls-manual"}]}}}'
kubectl -n search delete deployment legacy-indexer
am_app_refresh query-service hard
am_wait_app query-service sync=Synced health=Healthy --timeout 60

#!/bin/bash
# Wrong: the warning is silenced with a catch-all ignore rule (and the Deployment cleaned up). Nothing would ever be reported again.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject search-platform --type merge \
  -p '{"spec":{"orphanedResources":{"warn":true,"ignore":[{"group":"*","kind":"*","name":"*"}]}}}'
kubectl -n search delete deployment legacy-indexer
am_app_refresh query-service hard

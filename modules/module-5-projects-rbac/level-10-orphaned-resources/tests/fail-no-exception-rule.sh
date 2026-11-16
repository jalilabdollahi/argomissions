#!/bin/bash
# Wrong: the stray Deployment is gone and monitoring is on, but the documented Secret keeps being reported.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject search-platform --type merge -p '{"spec":{"orphanedResources":{"warn":true}}}'
kubectl -n search delete deployment legacy-indexer
am_app_refresh query-service hard
sleep 5

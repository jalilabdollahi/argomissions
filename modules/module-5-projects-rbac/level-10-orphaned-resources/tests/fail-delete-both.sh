#!/bin/bash
# Wrong: monitoring is enabled and everything the warning lists is deleted, including the documented TLS Secret.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject search-platform --type merge -p '{"spec":{"orphanedResources":{"warn":true}}}'
kubectl -n search delete deployment/legacy-indexer secret/search-tls-manual
am_app_refresh query-service hard

#!/bin/bash
# Wrong: the quickest way to a working pipeline is the admin session token. It "works", but it is not a project token.
set -euo pipefail
source "$AM_LIB"

token="$(grep -E 'auth-token:' "${ARGOCD_OPTS#--config }" | head -1 | awk '{print $3}')"
[ -n "$token" ]
kubectl -n settle-ci create secret generic argocd-pipeline-token --from-literal=token="$token" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

#!/bin/bash
# Wrong: a role with every action on every application of the project. The token works for sync, and for delete too.
set -euo pipefail
source "$AM_LIB"

am_argocd proj role create settlements deployer
am_argocd proj role add-policy settlements deployer --action '*' --permission allow --object '*'
token="$(am_argocd proj role create-token settlements deployer --token-only)"
kubectl -n settle-ci create secret generic argocd-pipeline-token --from-literal=token="$token" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

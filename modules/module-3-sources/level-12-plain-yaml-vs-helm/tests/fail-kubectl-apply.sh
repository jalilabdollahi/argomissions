#!/bin/bash
# Wrong: apply the manifests by hand. The portal runs, but Argo CD still renders it with Helm and owns nothing.
set -euo pipefail
source "$AM_LIB"

kubectl apply -n docs -f "$SANDBOX/docs-portal/deploy/deployment.yaml" -f "$SANDBOX/docs-portal/deploy/service.yaml"
kubectl -n docs rollout status deploy/docs-portal --timeout=90s

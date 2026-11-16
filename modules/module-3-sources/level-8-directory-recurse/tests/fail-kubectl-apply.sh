#!/bin/bash
# Wrong: apply the manifests by hand. The pods run, but Argo CD still renders nothing and owns nothing.
set -euo pipefail
source "$AM_LIB"

kubectl apply -n inventory -R -f "$SANDBOX/inventory-stack/deploy/"
kubectl -n inventory rollout status deploy/stock-web --timeout=90s

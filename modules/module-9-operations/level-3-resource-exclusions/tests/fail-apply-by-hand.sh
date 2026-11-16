#!/bin/bash
# Wrong: the ConfigMap is applied with kubectl; the pod starts, but Argo CD still cannot see ConfigMaps.
set -euo pipefail
source "$AM_LIB"

kubectl apply -n lexicon -f "$SANDBOX/lexicon-site/deploy/pages.yaml"
kubectl -n lexicon rollout status deploy/lexicon-site --timeout=90s

#!/bin/bash
# Wrong: the manifests applied by hand. It runs, but no Application owns it.
set -euo pipefail
source "$AM_LIB"

kubectl apply -n status -f "$SANDBOX/status-page/deploy/"
kubectl -n status rollout status deploy/status-page --timeout=90s

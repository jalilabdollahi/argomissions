#!/bin/bash
# Wrong: apply the ConfigMap server-side by hand. The pod starts, the Application knows nothing about it.
set -euo pipefail
source "$AM_LIB"

kubectl -n netops apply --server-side --force-conflicts -f "$SANDBOX/host-registry/deploy/host-inventory.yaml"
kubectl -n netops rollout status deploy/host-registry --timeout=90s

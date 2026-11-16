#!/bin/bash
# Wrong: scale the base deployment by hand; the path is still the base and the app is OutOfSync.
set -euo pipefail
source "$AM_LIB"

kubectl -n inventory scale deploy/inventory-sync --replicas=3
kubectl -n inventory rollout status deploy/inventory-sync --timeout=90s

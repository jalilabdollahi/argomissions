#!/bin/bash
# Wrong: re-apply the old plain manifests by hand to bring the name back.
set -euo pipefail
source "$AM_LIB"

kubectl apply -n fleet -f "$SANDBOX/fleet-tracker/manifests/"
kubectl -n fleet rollout status deploy/tracker-api --timeout=90s

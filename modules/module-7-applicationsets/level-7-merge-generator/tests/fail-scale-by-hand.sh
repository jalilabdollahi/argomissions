#!/bin/bash
# Wrong: production scaled by hand. Three pods run, but Git/the ApplicationSet still say one.
set -euo pipefail
source "$AM_LIB"

kubectl -n parcel-prod scale deploy/parcel-api --replicas=3
kubectl -n parcel-prod rollout status deploy/parcel-api --timeout=90s

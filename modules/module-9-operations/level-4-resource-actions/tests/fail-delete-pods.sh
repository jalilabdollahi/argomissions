#!/bin/bash
# Wrong: pods deleted one by one (with kubectl); they come back with the new value, but not via Argo CD.
set -euo pipefail
source "$AM_LIB"

kubectl -n tollbooth delete pod -l app=tollbooth --wait=true
kubectl -n tollbooth rollout status deploy/tollbooth --timeout=90s
am_wait_app tollbooth sync=Synced health=Healthy --timeout 120

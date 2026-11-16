#!/bin/bash
# Wrong: the pods are restarted with kubectl, which the on-call engineer is not supposed to have in production.
set -euo pipefail
source "$AM_LIB"

kubectl -n tollbooth rollout restart deploy/tollbooth
kubectl -n tollbooth rollout status deploy/tollbooth --timeout=90s
am_wait_app tollbooth sync=Synced health=Healthy --timeout 120

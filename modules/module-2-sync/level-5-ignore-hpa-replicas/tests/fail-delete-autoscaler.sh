#!/bin/bash
# Wrong: the other controller is removed instead of the conflict.
set -euo pipefail
source "$AM_LIB"

kubectl delete namespace quotes-scaler --wait=true
am_wait_app quote-api sync=Synced health=Healthy --timeout 150

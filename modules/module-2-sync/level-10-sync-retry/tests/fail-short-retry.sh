#!/bin/bash
# Wrong: a few more attempts, but still not long enough (limit 4 x 5s = 5+10+20+30).
set -euo pipefail
source "$AM_LIB"

am_argocd app set sensor-hub --sync-retry-limit 4 --sync-retry-backoff-duration 5s \
  --sync-retry-backoff-factor 2 --sync-retry-backoff-max-duration 30s
am_wait 240 kubectl get crd sensorprofiles.runtime.argomissions.io
sleep 5
am_argocd app sync sensor-hub --timeout 120
am_wait_app sensor-hub sync=Synced health=Healthy op=Succeeded --timeout 120

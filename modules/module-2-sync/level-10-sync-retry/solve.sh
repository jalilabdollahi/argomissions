#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# retry for ~6 minutes: 10s, 20s, 40s, then 60s (cap) x5
am_argocd app set sensor-hub --sync-retry-limit 8 --sync-retry-backoff-duration 10s \
  --sync-retry-backoff-factor 2 --sync-retry-backoff-max-duration 60s
# a failed operation is not retried by itself: start a new one (carries the new retry policy)
am_argocd app sync sensor-hub --timeout 400
am_wait_app sensor-hub sync=Synced health=Healthy op=Succeeded --timeout 300

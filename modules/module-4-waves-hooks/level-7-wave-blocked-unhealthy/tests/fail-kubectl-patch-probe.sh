#!/bin/bash
# Wrong: hot-patch the live Deployment's probe. The stuck wave moves on, but Git still has the bad probe.
set -euo pipefail
source "$AM_LIB"

kubectl -n fleet patch deployment tracker-api --type json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/port","value":5678}]'
kubectl -n fleet rollout status deploy/tracker-api --timeout=90s
am_wait_app fleet-tracker op=Succeeded --timeout 120 || true
am_app_refresh fleet-tracker
sleep 5

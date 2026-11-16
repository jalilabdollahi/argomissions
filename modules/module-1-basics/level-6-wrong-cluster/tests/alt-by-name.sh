#!/bin/bash
# Correct too: destination by cluster name in-cluster instead of by URL.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application telemetry --type json \
  -p '[{"op":"remove","path":"/spec/destination/server"},{"op":"add","path":"/spec/destination/name","value":"in-cluster"}]'
am_app_refresh telemetry
am_argocd app sync telemetry --timeout 120
am_wait_app telemetry sync=Synced health=Healthy --timeout 120

#!/bin/bash
# Wrong: guess another cluster name that is not registered either.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application telemetry --type json \
  -p '[{"op":"remove","path":"/spec/destination/server"},{"op":"add","path":"/spec/destination/name","value":"kubernetes"}]'
am_app_refresh telemetry
am_wait_app telemetry cond="InvalidSpecError" --timeout 60

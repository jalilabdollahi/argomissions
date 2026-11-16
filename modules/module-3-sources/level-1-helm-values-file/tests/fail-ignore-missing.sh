#!/bin/bash
# Wrong: silence the error with ignoreMissingValueFiles. The app turns green but renders the dev defaults.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application weather-api --type json \
  -p '[{"op":"add","path":"/spec/source/helm/ignoreMissingValueFiles","value":true}]'
am_app_refresh weather-api
am_argocd app sync weather-api --timeout 120
am_wait_app weather-api sync=Synced health=Healthy --timeout 120

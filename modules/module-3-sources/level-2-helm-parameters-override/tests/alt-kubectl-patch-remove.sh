#!/bin/bash
# Correct too: the declarative equivalent, removing the parameters list from the Application.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application media-gateway --type json -p '[{"op":"remove","path":"/spec/source/helm"}]'
am_app_refresh media-gateway
sleep 3
am_wait_app media-gateway sync=Synced health=Healthy --timeout 120
kubectl -n media rollout status deploy/media-gateway --timeout=90s

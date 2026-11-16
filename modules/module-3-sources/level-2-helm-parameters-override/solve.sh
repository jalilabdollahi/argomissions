#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app unset media-gateway -p release.version
# automated sync rolls the new render out by itself
sleep 3
am_wait_app media-gateway sync=Synced health=Healthy --timeout 120
kubectl -n media rollout status deploy/media-gateway --timeout=90s

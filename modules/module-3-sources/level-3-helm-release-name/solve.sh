#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set fleet-tracker --release-name tracker
sleep 3
am_wait_app fleet-tracker sync=Synced health=Healthy --timeout 150
kubectl -n fleet rollout status deploy/tracker-api --timeout=90s

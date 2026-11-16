#!/bin/bash
# Correct too: helm.releaseName set declaratively on the Application.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application fleet-tracker --type merge -p '{"spec":{"source":{"helm":{"releaseName":"tracker"}}}}'
am_app_refresh fleet-tracker
sleep 3
am_wait_app fleet-tracker sync=Synced health=Healthy --timeout 150
kubectl -n fleet rollout status deploy/tracker-api --timeout=90s

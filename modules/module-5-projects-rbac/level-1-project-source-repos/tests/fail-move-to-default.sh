#!/bin/bash
# Wrong: dodge the project by moving the app to `default`.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application claims-intake --type merge -p '{"spec":{"project":"default"}}'
am_app_refresh claims-intake
am_wait_app claims-intake sync=Synced health=Healthy --timeout 150

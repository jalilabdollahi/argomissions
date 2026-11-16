#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app actions list tollbooth --kind Deployment --resource-name tollbooth
am_argocd app actions run tollbooth restart --kind Deployment --resource-name tollbooth
kubectl -n tollbooth rollout status deploy/tollbooth --timeout=90s
am_wait_app tollbooth sync=Synced health=Healthy --timeout 120

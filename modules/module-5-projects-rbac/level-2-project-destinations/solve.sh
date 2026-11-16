#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd proj add-destination clinic https://kubernetes.default.svc pharmacy
am_app_refresh rx-dispatch
am_wait_app rx-dispatch sync=Synced health=Healthy --timeout 150

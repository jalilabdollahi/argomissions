#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set host-registry --sync-option ServerSideApply=true
am_argocd app sync host-registry --timeout 120
am_wait_app host-registry sync=Synced health=Healthy --timeout 120

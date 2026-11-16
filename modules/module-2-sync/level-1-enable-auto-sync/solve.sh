#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set metrics-gw --sync-policy automated
am_wait_app metrics-gw sync=Synced health=Healthy --timeout 120

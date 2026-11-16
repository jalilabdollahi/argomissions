#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set gallery-web --auto-prune
am_wait_app gallery-web sync=Synced health=Healthy --timeout 120

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app diff media || true
am_argocd app sync media --prune --timeout 120
am_wait_app media sync=Synced health=Healthy --timeout 120

#!/bin/bash
# Wrong: one manual sync catches up with main, but the policy stays manual.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync metrics-gw --timeout 120
am_wait_app metrics-gw sync=Synced health=Healthy --timeout 120

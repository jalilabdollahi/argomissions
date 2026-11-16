#!/bin/bash
# Wrong: a plain sync re-applies all 11 objects and resets the counter; fixing the option afterwards is too late.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync region-configs --timeout 120
am_wait_app region-configs sync=Synced health=Healthy --timeout 120
am_argocd app set region-configs --sync-option ApplyOutOfSyncOnly=true

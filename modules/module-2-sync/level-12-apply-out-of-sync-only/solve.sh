#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# set the option BEFORE syncing: a plain sync would reset the counter again
am_argocd app set region-configs --sync-option ApplyOutOfSyncOnly=true
am_argocd app sync region-configs --timeout 120
am_wait_app region-configs sync=Synced health=Healthy --timeout 120

#!/bin/bash
# Correct too: the option written into the Application, sync started like the UI button.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application region-configs --type merge -p '{"spec":{"syncPolicy":{"syncOptions":["ApplyOutOfSyncOnly=true"]}}}'
am_app_sync_now region-configs
am_wait_app region-configs sync=Synced health=Healthy op=Succeeded --timeout 120

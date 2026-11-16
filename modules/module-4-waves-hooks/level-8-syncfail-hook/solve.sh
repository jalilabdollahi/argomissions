#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app get booking-portal --show-operation || true
cd "$SANDBOX/booking-portal"
git pull -q
sed -i.bak 's/hook: PostSync/hook: PostSync,SyncFail/' deploy/exit-maintenance.yaml && rm -f deploy/exit-maintenance.yaml.bak
am_player_push . "exit-maintenance: also run when the sync fails"
head="$(am_repo_head booking-portal)"
am_app_refresh booking-portal
am_wait_app booking-portal rev="$head" --timeout 120
am_argocd app sync booking-portal --timeout 120 || true     # fails at the schema gate, as designed
am_wait 90 bash -c "[ \"\$(source '$AM_LIB'; am_app booking-portal '{.status.operationState.syncResult.revision}')\" = '$head' ] && ! kubectl -n bookings get configmap maintenance-flag"

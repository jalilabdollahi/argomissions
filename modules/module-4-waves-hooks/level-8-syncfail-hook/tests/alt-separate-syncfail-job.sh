#!/bin/bash
# Correct too: keep the PostSync job and add a second, SyncFail-only job.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/booking-portal"
sed -e 's/name: exit-maintenance/name: abort-maintenance/' -e 's/hook: PostSync/hook: SyncFail/' \
  deploy/exit-maintenance.yaml > deploy/abort-maintenance.yaml
am_player_push . "add abort-maintenance SyncFail hook"
head="$(am_repo_head booking-portal)"
am_app_refresh booking-portal
am_wait_app booking-portal rev="$head" --timeout 120
am_argocd app sync booking-portal --timeout 120 || true
am_wait 90 bash -c "[ \"\$(source '$AM_LIB'; am_app booking-portal '{.status.operationState.syncResult.revision}')\" = '$head' ] && ! kubectl -n bookings get configmap maintenance-flag"

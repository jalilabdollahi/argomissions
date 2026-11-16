#!/bin/bash
# Wrong: service, template and trigger are in place, but nobody subscribed the Application to the trigger.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-notifications-cm --type merge --patch-file "$LEVEL_DIR/assets/notifications-patch.yaml"
sleep 5
am_app_sync_now payout-worker
am_wait_app payout-worker op=Failed --timeout 60
sleep 15

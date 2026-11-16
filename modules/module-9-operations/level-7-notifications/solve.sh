#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-notifications-cm --type merge --patch-file "$LEVEL_DIR/assets/notifications-patch.yaml"
kubectl -n argocd annotate application payout-worker 'notifications.argoproj.io/subscribe.on-sync-failed.chat-hook=' --overwrite
# The app is still failing: run the sync again, as a person would, to see the notification leave.
sleep 5
am_app_sync_now payout-worker
delivered() { kubectl -n ops-hooks logs deploy/chat-hook | grep -q ' POST /hooks/deploys '; }
am_wait 90 delivered

#!/bin/bash
# Wrong: everything is wired, but the template posts to a path the receiver is not listening on.
set -euo pipefail
source "$AM_LIB"

sed 's#/hooks/deploys#/hook#' "$LEVEL_DIR/assets/notifications-patch.yaml" >"$AM_TMP/patch.yaml"
kubectl -n argocd patch configmap argocd-notifications-cm --type merge --patch-file "$AM_TMP/patch.yaml"
kubectl -n argocd annotate application payout-worker 'notifications.argoproj.io/subscribe.on-sync-failed.chat-hook=' --overwrite
sleep 5
am_app_sync_now payout-worker
am_wait_app payout-worker op=Failed --timeout 60
sleep 20

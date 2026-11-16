#!/bin/bash
# Correct too: a default subscription in the notifications ConfigMap instead of an annotation on the app.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-notifications-cm --type merge --patch-file "$LEVEL_DIR/assets/notifications-patch.yaml"
kubectl -n argocd patch configmap argocd-notifications-cm --type merge -p \
  '{"data":{"subscriptions":"- recipients:\n  - chat-hook\n  triggers:\n  - on-sync-failed\n"}}'
sleep 5
am_app_sync_now payout-worker
delivered() { kubectl -n ops-hooks logs deploy/chat-hook | grep -q ' POST /hooks/deploys '; }
am_wait 90 delivered

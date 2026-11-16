#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=payout-worker

am_app_exists "$APP" || am_fail "Application '$APP' does not exist"
kubectl -n ops-hooks get deploy chat-hook >/dev/null 2>&1 || am_fail "The chat-hook receiver in namespace ops-hooks is gone"

# Notifications must be configured in Argo CD itself: a webhook service, a trigger, and a subscription.
kubectl -n argocd get configmap argocd-notifications-cm -o json >"$AM_TMP/cm.json" 2>/dev/null
jq -e '.data // {} | keys | map(select(startswith("service.webhook."))) | length > 0' "$AM_TMP/cm.json" >/dev/null \
  || am_fail "argocd-notifications-cm defines no webhook service"
jq -e '.data // {} | to_entries | map(select(.key | startswith("service.webhook.")) | .value | contains("chat-hook.ops-hooks")) | any' "$AM_TMP/cm.json" >/dev/null \
  || am_fail "No webhook service in argocd-notifications-cm points at the chat-hook receiver"
jq -e '.data // {} | keys | map(select(startswith("trigger."))) | length > 0' "$AM_TMP/cm.json" >/dev/null \
  || am_fail "argocd-notifications-cm defines no trigger"
am_ok "argocd-notifications-cm has a webhook service for chat-hook and a trigger"

subscribed="$(am_app_json "$APP" | jq -r '[.metadata.annotations // {} | keys[] | select(startswith("notifications.argoproj.io/subscribe."))] | length')"
global="$(jq -r '.data.subscriptions // ""' "$AM_TMP/cm.json" | grep -c . || true)"
{ [ "${subscribed:-0}" -gt 0 ] || [ "${global:-0}" -gt 0 ]; } \
  || am_fail "Application '$APP' is not subscribed to any trigger, and no default subscription exists"
am_ok "Application '$APP' is subscribed"

# What counts is what arrived: a POST to /hooks/deploys, from a failed sync of the app.
kubectl -n ops-hooks logs deploy/chat-hook >"$AM_TMP/hook.log" 2>/dev/null || am_fail "cannot read the receiver log"
grep -E ' POST ' "$AM_TMP/hook.log" >"$AM_TMP/posts.log" || true
[ -s "$AM_TMP/posts.log" ] || am_fail "The chat-hook receiver has not received any notification from Argo CD yet"
grep -q ' POST /hooks/deploys ' "$AM_TMP/posts.log" \
  || am_fail "The receiver got POST requests, but none on the path /hooks/deploys: $(awk '{print $3}' "$AM_TMP/posts.log" | sort -u | tr '\n' ' ')"
grep ' POST /hooks/deploys ' "$AM_TMP/posts.log" | grep -q "$APP" \
  || am_fail "No notification on /hooks/deploys mentions the application '$APP'"
grep ' POST /hooks/deploys ' "$AM_TMP/posts.log" | grep "$APP" | grep -qiE 'fail|error' \
  || am_fail "The notifications for '$APP' do not say that a sync failed"
am_pass "A failed sync of '$APP' reached chat-hook"

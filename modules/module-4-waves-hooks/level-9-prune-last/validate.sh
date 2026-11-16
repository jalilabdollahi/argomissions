#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=chat-relay
am_require_app_at_head "$APP" chat-relay

head="$(am_repo_head chat-relay)"
synced="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"
[ "$synced" = "$head" ] || am_fail "The last sync of '$APP' deployed ${synced:0:7}, but main is at ${head:0:7}"
[ "$(am_app_op "$APP")" = Succeeded ] || am_fail "The last sync operation of '$APP' did not succeed"

kubectl -n chat get service relay >/dev/null 2>&1 && am_fail "Service relay still exists in namespace chat: the rename was never completed"
kubectl -n chat get deployment relay >/dev/null 2>&1 && am_fail "Deployment relay still exists in namespace chat: the rename was never completed"
am_ok "The old Service and Deployment are gone"

hook="$(am_app_json "$APP" | jq -c '[.status.operationState.syncResult.resources[]? | select(.kind=="Job" and .name=="handover-check")][0] // {}')"
[ "$hook" != "{}" ] || am_fail "The last sync did not run Job handover-check"
[ "$(echo "$hook" | jq -r '.hookPhase')" = Succeeded ] || am_fail "Job handover-check ended in phase '$(echo "$hook" | jq -r '.hookPhase')'"
line="$(kubectl -n chat logs job/handover-check 2>/dev/null | grep '^handover:' | tail -1)"
[ -n "$line" ] || am_fail "Job handover-check left no result in namespace chat"
case "$line" in
  *"relay=up"*"relay-gateway=up"*) am_ok "During the cut-over both names answered ($line)" ;;
  *"relay=down"*) am_fail "During the last cut-over the old Service relay was already gone when the new one came up ($line): clients had an outage window" ;;
  *) am_fail "During the last cut-over the new Service relay-gateway did not answer ($line)" ;;
esac

[ "$(am_ready_replicas relay-gateway chat)" -ge 1 ] || am_fail "Deployment relay-gateway in namespace chat has no ready pod"
body="$(am_http http://relay-gateway.chat chat)" || am_fail "Service relay-gateway in namespace chat does not answer"
[ "$body" = "chat-relay v2.0" ] || am_fail "Service relay-gateway answers '$body'"
am_pass "chat-relay v2.0 is live and the rename had no outage window"

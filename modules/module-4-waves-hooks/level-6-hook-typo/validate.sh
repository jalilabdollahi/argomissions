#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=ticket-desk
am_require_app_at_head "$APP" ticket-desk

head="$(am_repo_head ticket-desk)"
synced="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"
[ "$synced" = "$head" ] || am_fail "The last sync of '$APP' deployed ${synced:0:7}, but main is at ${head:0:7}: no sync has run since the latest commit"

res="$(am_app_json "$APP" | jq -c '[.status.operationState.syncResult.resources[]? | select(.kind=="Job" and .name=="reindex-tickets")][0] // {}')"
[ "$res" != "{}" ] || am_fail "The last sync of '$APP' never touched Job reindex-tickets: the reindex did not run as part of a sync"
[ "$(echo "$res" | jq -r '.hookType // empty')" = PreSync ] \
  || am_fail "Job reindex-tickets took part in the last sync, but not as a PreSync hook (it must finish before the rollout)"
[ "$(echo "$res" | jq -r '.hookPhase // empty')" = Succeeded ] \
  || am_fail "The reindex-tickets hook ended in phase '$(echo "$res" | jq -r '.hookPhase')', not Succeeded"
am_ok "Job reindex-tickets ran as a PreSync hook in the sync of ${head:0:7} and succeeded"

kubectl -n helpdesk logs job/reindex-tickets 2>/dev/null | grep -q "index rebuilt" \
  || am_fail "The reindex-tickets Job left no 'index rebuilt' log line in namespace helpdesk"
am_ok "The reindex finished (log: index rebuilt)"

[ "$(am_ready_replicas ticket-desk helpdesk)" -ge 1 ] || am_fail "Deployment ticket-desk in namespace helpdesk has no ready pod"
body="$(am_http http://ticket-desk.helpdesk helpdesk)" || am_fail "Service ticket-desk in namespace helpdesk does not answer"
[ "$body" = "ticket-desk v3.1" ] || am_fail "Service ticket-desk answers '$body'"
am_pass "ticket-desk v3.1 is live and the reindex ran before the rollout"

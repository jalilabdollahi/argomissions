#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=booking-portal
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"
head="$(am_repo_head booking-portal)"
synced="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"
[ "$synced" = "$head" ] || am_fail "The last sync of '$APP' ran ${synced:0:7}, but main is at ${head:0:7}: the current head has not been synced yet"

phase="$(am_app_op "$APP")"
[ "$phase" = Failed ] || am_fail "The last sync of '$APP' ended in phase ${phase:-unknown}: release v5.2 is expected to still fail its schema gate (that is the DBA team's problem, not part of this mission)"
gate="$(am_app_json "$APP" | jq -r '[.status.operationState.syncResult.resources[]? | select(.kind=="Job" and .name=="schema-gate")][0].hookPhase // empty')"
[ "$gate" = Failed ] || am_fail "Job schema-gate did not fail in the last sync (phase '${gate:-none}'): the failing release must stay as it is"
am_ok "The sync of ${head:0:7} failed at the schema gate, as expected"

hook="$(am_app_json "$APP" | jq -c '[.status.operationState.syncResult.resources[]? | select(.kind=="Job" and .hookType=="SyncFail")][0] // {}')"
[ "$hook" != "{}" ] || am_fail "The failed sync ran no failure hook: nothing reacted to the failure"
[ "$(echo "$hook" | jq -r '.hookPhase')" = Succeeded ] || am_fail "The failure hook '$(echo "$hook" | jq -r '.name')' ended in phase '$(echo "$hook" | jq -r '.hookPhase')'"
am_ok "Failure hook $(echo "$hook" | jq -r '.name') ran after the failed sync and succeeded"

if kubectl -n bookings get configmap maintenance-flag >/dev/null 2>&1; then
  am_fail "ConfigMap maintenance-flag still exists in namespace bookings: the site is still in maintenance"
fi
am_pass "the failed sync lowered the maintenance banner by itself"

#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=booking-web
NS=booking
JOB=booking-web-smoke-test

am_require_app_at_head "$APP" booking-web

head="$(am_repo_head booking-web)"
synced="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"
[ "$synced" = "$head" ] || am_fail "The last sync of '$APP' deployed ${synced:0:7}, but main is at ${head:0:7}"
op="$(am_app_op "$APP")"
[ "$op" = Succeeded ] || am_fail "The last sync operation of '$APP' is ${op:-unknown}, not Succeeded: $(am_app "$APP" '{.status.operationState.message}')"
am_ok "The last sync of the head commit Succeeded"

# The smoke test must still exist, run after the sync and pass.
passed="$(am_app_json "$APP" | jq -r --arg job "$JOB" '[.status.operationState.syncResult.resources[]? | select(.kind=="Job" and .name==$job and .hookType=="PostSync" and .hookPhase=="Succeeded")] | length')"
[ "$passed" != 0 ] || am_fail "The last sync of '$APP' did not run a passing PostSync smoke test (Job $JOB)"
am_ok "The PostSync smoke test ran and passed"

am_repo_checkout booking-web "$AM_TMP/git" >/dev/null 2>&1 || am_fail "cannot clone booking-web"
am_yaml_docs_json "$AM_TMP/git/deploy" >"$AM_TMP/docs.json"
cmd="$(jq -r --arg job "$JOB" '[.[] | select(.kind=="Job" and .metadata.name==$job)][0] | (.spec.template.spec.containers[0].command // []) + (.spec.template.spec.containers[0].args // []) | join(" ")' "$AM_TMP/docs.json")"
[[ "$cmd" == *curl* ]] || am_fail "The smoke test in Git no longer calls the Service"
[[ "$cmd" == *booking-web* ]] || am_fail "The smoke test in Git does not test the booking-web Service"
if [[ "$cmd" == *"|| true"* || "$cmd" == *"exit 0"* || "$cmd" == *";true"* || "$cmd" == *"; true"* ]]; then
  am_fail "The smoke test in Git swallows its own errors: a test that cannot fail tests nothing"
fi
am_ok "The smoke test in Git is a real check of the Service"

[ "$(am_ready_replicas booking-web "$NS")" -ge 1 ] || am_fail "Deployment booking-web in namespace $NS has no ready pod"
body="$(am_http http://booking-web.$NS "$NS")" || am_fail "Service booking-web in namespace $NS does not answer on port 80"
[ "$body" = "booking-web v1.4" ] || am_fail "Service booking-web answers '$body'"
am_pass "booking-web is live and its smoke test gates the sync"

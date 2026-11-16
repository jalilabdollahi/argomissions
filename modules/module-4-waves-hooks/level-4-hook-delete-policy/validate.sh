#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=helpdesk-api
NS=helpdesk
JOB=helpdesk-db-migrate

am_require_app_at_head "$APP" helpdesk-api

head="$(am_repo_head helpdesk-api)"
synced="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"
[ "$synced" = "$head" ] || am_fail "The last sync of '$APP' deployed ${synced:0:7}, but main is at ${head:0:7}"
[ "$(am_app_op "$APP")" = Succeeded ] || am_fail "The last sync operation of '$APP' is $(am_app_op "$APP"), not Succeeded"
hook_ok="$(am_app_json "$APP" | jq -r --arg job "$JOB" '[.status.operationState.syncResult.resources[]? | select(.kind=="Job" and .name==$job and .hookType=="PreSync" and .hookPhase=="Succeeded")] | length')"
[ "$hook_ok" != 0 ] || am_fail "The last sync of '$APP' did not run the migration Job $JOB to completion"
am_ok "The head commit was synced and the migration hook ran"

# Git: a finished run of the hook must not block the next one.
am_repo_checkout helpdesk-api "$AM_TMP/git" >/dev/null 2>&1 || am_fail "cannot clone helpdesk-api"
am_yaml_docs_json "$AM_TMP/git/deploy" >"$AM_TMP/docs.json"
state="$(jq -r --arg job "$JOB" '
  (map(select(.kind=="Job" and .metadata.name==$job))[0]) as $j
  | if $j == null then "missing"
    else ((($j.metadata.annotations // {})["argocd.argoproj.io/hook"] // "") ) as $h
      | ((($j.metadata.annotations // {})["argocd.argoproj.io/hook-delete-policy"]) // "") as $p
      | if ($h|test("PreSync")|not) then "nohook"
        elif $p == "" then "ok"
        elif ($p|test("BeforeHookCreation|HookSucceeded")) then "ok"
        else "stale" end
    end' "$AM_TMP/docs.json")"
case "$state" in
  ok) am_ok "In Git, the migration hook is cleaned up before or after each run" ;;
  missing) am_fail "Job $JOB is gone from the repo: the migration must remain" ;;
  nohook) am_fail "In Git, Job $JOB is no longer a PreSync hook" ;;
  *) am_fail "In Git, a finished run of Job $JOB stays in the cluster and the next change to the Job will be rejected again" ;;
esac

[ "$(am_ready_replicas helpdesk-api "$NS")" -ge 1 ] || am_fail "Deployment helpdesk-api in namespace $NS has no ready pod"
body="$(am_http http://helpdesk-api.$NS "$NS")" || am_fail "Service helpdesk-api in namespace $NS does not answer"
[ "$body" = "helpdesk-api v2" ] || am_fail "Service helpdesk-api answers '$body'"
am_pass "helpdesk-api v2 is live and the migration hook can run on every release"

#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=payroll-api
NS=payroll
JOB=payroll-schema-migrate

am_require_app_at_head "$APP" payroll-api

head="$(am_repo_head payroll-api)"
synced="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"
[ "$synced" = "$head" ] || am_fail "The last sync of '$APP' deployed ${synced:0:7}, but main is at ${head:0:7}: release v2 was not shipped through Argo CD"
[ "$(am_app_op "$APP")" = Succeeded ] || am_fail "The last sync operation of '$APP' is $(am_app_op "$APP"), not Succeeded"
am_ok "Release v2 was shipped by an Argo CD sync"

# Git must order the migration before the Deployment (hook phase or an earlier wave).
am_repo_checkout payroll-api "$AM_TMP/git" >/dev/null 2>&1 || am_fail "cannot clone payroll-api"
am_yaml_docs_json "$AM_TMP/git/deploy" >"$AM_TMP/docs.json"
jq -r --arg job "$JOB" '
  def wave: ((.metadata.annotations // {})["argocd.argoproj.io/sync-wave"] // "0") | tonumber? // 0;
  def hooks: ((.metadata.annotations // {})["argocd.argoproj.io/hook"] // "");
  (map(select(.kind=="Job" and .metadata.name==$job))[0]) as $j
  | (map(select(.kind=="Deployment"))[0]) as $d
  | if $j == null then "missing"
    elif ($j|hooks|test("PreSync")) then "ok"
    elif ($j|hooks) != "" then "other-hook"
    elif ($j|wave) < ($d|wave) then "ok"
    else "unordered" end' "$AM_TMP/docs.json" >"$AM_TMP/order.txt" 2>/dev/null
case "$(cat "$AM_TMP/order.txt")" in
  ok) am_ok "In Git, the migration Job is ordered before the Deployment" ;;
  missing) am_fail "Job $JOB is gone from the repo: the migration must still be part of the release" ;;
  *) am_fail "In Git, nothing makes the migration Job finish before the Deployment is rolled out: both are applied at the same time" ;;
esac

# Live proof: the Job completed before the Deployment's current ReplicaSet was created.
hook_ok="$(am_app_json "$APP" | jq -r --arg job "$JOB" '[.status.operationState.syncResult.resources[]? | select(.kind=="Job" and .name==$job and .hookType=="PreSync" and .hookPhase=="Succeeded")] | length')"
if [ "$hook_ok" = 0 ]; then
  done_at="$(kubectl -n "$NS" get job "$JOB" -o jsonpath='{.status.completionTime}' 2>/dev/null)"
  [ -n "$done_at" ] || am_fail "Job $JOB in namespace $NS has not completed"
  rev="$(kubectl -n "$NS" get deploy payroll-api -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')"
  rs_at="$(kubectl -n "$NS" get rs -l app=payroll-api -o json | jq -r --arg rev "$rev" '[.items[] | select(.metadata.annotations["deployment.kubernetes.io/revision"]==$rev)][0].metadata.creationTimestamp')"
  [[ "$rs_at" > "$done_at" || "$rs_at" = "$done_at" ]] \
    || am_fail "Release v2 started rolling out at $rs_at, before the migration Job finished at $done_at"
fi
am_ok "The migration Job finished before release v2 rolled out"

[ "$(am_ready_replicas payroll-api "$NS")" -ge 1 ] || am_fail "Deployment payroll-api in namespace $NS has no ready pod"
body="$(am_http http://payroll-api.$NS "$NS")" || am_fail "Service payroll-api in namespace $NS does not answer"
[ "$body" = "payroll-api v2" ] || am_fail "Service payroll-api answers '$body'"
am_pass "payroll-api v2 is live and the schema was migrated first"

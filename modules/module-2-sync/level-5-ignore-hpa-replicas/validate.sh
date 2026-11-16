#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=quote-api
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

# the autoscaler is somebody else's controller: it must still be there doing its job
[ "$(kubectl -n quotes-scaler get deploy load-scaler -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)" = 1 ] \
  || am_fail "The platform's autoscaler (load-scaler in namespace quotes-scaler) is not running: the fight was not resolved, it was removed"
am_ok "the autoscaler keeps running"

app_json="$(am_app_json "$APP")"
[ "$(echo "$app_json" | jq -r '.spec.syncPolicy.automated.selfHeal // false')" = true ] \
  || am_fail "Application '$APP' no longer heals drift: the team wants self-heal to stay on for everything else"
am_ok "self-heal is still on"

am_repo_checkout quote-api "$AM_TMP/repo" || am_fail "cannot clone the quote-api repo"
docs="$(am_yaml_docs_json "$AM_TMP/repo/deploy")"
dep="$(echo "$docs" | jq -c '[.[] | select(.kind=="Deployment" and .metadata.name=="quote-api")][0]')"
[ "$dep" != null ] || am_fail "The quote-api Deployment is gone from Git"
git_replicas="$(echo "$dep" | jq -r '.spec.replicas // "unset"')"

if [ "$git_replicas" = unset ]; then
  am_ok "Git does not pin the replica count any more"
else
  ignores="$(echo "$app_json" | jq '[.spec.ignoreDifferences[]?
      | select((.group // "apps") == "apps" and (.kind // "Deployment") == "Deployment" and (.name // "quote-api") == "quote-api")
      | select(((.jsonPointers // []) | index("/spec/replicas")) != null
            or ((.jqPathExpressions // []) | map(gsub("\\s";"")) | index(".spec.replicas")) != null
            or ((.managedFieldsManagers // []) | index("load-scaler")) != null)] | length')"
  [ "$ignores" -ge 1 ] \
    || am_fail "Git pins replicas to $git_replicas and the Application has no rule about who owns that field: the autoscaler and Argo CD will keep overwriting each other"
  echo "$app_json" | jq -e '(.spec.syncPolicy.syncOptions // []) | index("RespectIgnoreDifferences=true")' >/dev/null \
    || am_fail "The Application ignores the replica difference in its comparison, but a sync caused by any other change would still push Git's $git_replicas replicas over the autoscaler's"
  am_ok "the replica count is excluded from comparison and from syncs"
fi

# no flapping: the replica count must be the autoscaler's number and stay there
am_wait 90 bash -c "[ \"\$(kubectl -n quotes get deploy quote-api -o jsonpath='{.status.readyReplicas}')\" = 4 ]" \
  || am_fail "Deployment quote-api has $(am_ready_replicas quote-api quotes) ready replicas, the autoscaler wants 4"
am_wait 40 bash -c "[ \"\$(kubectl -n argocd get application quote-api -o jsonpath='{.status.health.status}')\" = Healthy ]" || true
am_require_app_at_head "$APP" quote-api
g1="$(am_jsonpath deploy/quote-api '{.metadata.generation}' quotes)"
sleep 15
g2="$(am_jsonpath deploy/quote-api '{.metadata.generation}' quotes)"
[ "$g1" = "$g2" ] || am_fail "The Deployment spec is still being rewritten (generation $g1 → $g2 in 15 s): Argo CD and the autoscaler are still fighting"
[ "$(am_jsonpath deploy/quote-api '{.spec.replicas}' quotes)" = 4 ] || am_fail "Deployment quote-api does not hold the autoscaler's 4 replicas"
[ "$(am_app_sync "$APP")" = Synced ] || am_fail "Application '$APP' is $(am_app_sync "$APP") (expected Synced)"
am_ok "4 replicas, stable, Application Synced"

body="$(am_http http://quote-api.quotes quotes)" || am_fail "Service quote-api in namespace quotes does not answer"
[ "$body" = "quote-api v5.0" ] || am_fail "Service quote-api answers '$body'"
am_pass "Argo CD and the autoscaler share the Deployment peacefully"

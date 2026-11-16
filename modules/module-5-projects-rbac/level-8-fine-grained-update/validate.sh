#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=rewards-engine
BASE="http://$AM_ARGOCD_ADDR/api/v1"

mira_token() {
  curl -s -X POST -H 'Content-Type: application/json' "$BASE/session" \
    -d '{"username":"mira","password":"mira-pw-4821"}' | jq -r '.token // empty'
}
# api METHOD PATH [BODY] -> HTTP status of an Argo CD API call made as mira.
# Argo CD checks RBAC before it looks the resource up: a resource that does not exist answers 404 when the call
# is allowed and 403 when it is not, so these probes never touch anything in the cluster.
api() {
  local tok; tok="$(mira_token)"
  [ -n "$tok" ] || { echo 000; return; }
  curl -s -o /dev/null -w '%{http_code}' -X "$1" -H 'Content-Type: application/json' -H "Authorization: Bearer $tok" \
    "$BASE/applications/$APP$2" ${3:+-d "$3"}
}
res() { echo "/resource?namespace=rewards&resourceName=ghost&version=v1&kind=$1&group=$2"; }
act() { echo "/resource/actions?namespace=rewards&resourceName=ghost&version=v1&kind=Deployment&group=apps"; }
# Policy changes take a few seconds to reach the API server, hence the retries.
allowed() { local i st; for i in 1 2 3 4 5 6; do st="$(api "$@")"; [ "$st" != 403 ] && [ "$st" != 000 ] && return 0; sleep 2; done; return 1; }
denied()  { local i st; for i in 1 2 3 4 5 6; do st="$(api "$@")"; [ "$st" = 403 ] && return 0; sleep 2; done; return 1; }

am_require_app_at_head "$APP" rewards-engine
[ -n "$(mira_token)" ] || am_fail "Cannot log in as 'mira' (password mira-pw-4821)"

# What she had must stay.
[ "$(api PATCH '' '{"patch":"{}","patchType":"merge"}')" != 403 ] \
  || am_fail "mira can no longer update the Application - her existing permissions must stay"

allowed POST "$(act)" '"restart"' || am_fail "mira is refused (permission denied) when she runs the 'restart' action on a Deployment"
am_ok "mira may run the restart action on Deployments"
allowed DELETE "$(res Pod '')" || am_fail "mira is refused (permission denied) when she deletes a Pod of the Application"
am_ok "mira may delete Pods of the Application"

denied DELETE "$(res Secret '')"        || am_fail "mira may delete Secrets managed by the Application - more than on-call needs"
denied DELETE "$(res Deployment apps)"  || am_fail "mira may delete Deployments managed by the Application - more than on-call needs"
denied DELETE "$(res ConfigMap '')"     || am_fail "mira may delete ConfigMaps managed by the Application - more than on-call needs"
am_ok "mira cannot delete anything but Pods"
denied POST "$(act)" '"scale"'          || am_fail "mira may run actions other than restart (such as scale) on Deployments"
am_ok "mira cannot run other resource actions"

as_mira() { env -u ARGOCD_OPTS argocd "$@" --config "$AM_TMP/mira-cli" --plaintext; }
as_mira login "$AM_ARGOCD_ADDR" --username mira --password mira-pw-4821 >/dev/null 2>&1 \
  || am_fail "Cannot log in as 'mira' with the CLI"
for check in "get applications loyalty/$APP" "sync applications loyalty/$APP" "update applications loyalty/$APP"; do
  [ "$(as_mira account can-i $check 2>/dev/null)" = yes ] || am_fail "mira lost '${check%% *}' on the Applications of her project"
done
for check in "delete applications loyalty/$APP" "create applications loyalty/$APP"; do
  [ "$(as_mira account can-i $check 2>/dev/null)" = no ] || am_fail "mira is allowed to ${check%% *} Applications - far more than on-call needs"
done
am_pass "mira has her on-call powers back, and only those"

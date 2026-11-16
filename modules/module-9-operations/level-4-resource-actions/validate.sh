#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=tollbooth NS=tollbooth
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"
since="$(kubectl get namespace "$NS" -o jsonpath='{.metadata.annotations.tollbooth\.argomissions\.io/setup-epoch}' 2>/dev/null || true)"
[ -n "$since" ] || am_fail "Namespace $NS lost its setup marker: the scenario was tampered with"

old="$(kubectl -n "$NS" get pods -l app=tollbooth -o json | jq --argjson t "$since" \
  '[.items[] | select(.metadata.deletionTimestamp == null) | select((.metadata.creationTimestamp | fromdateiso8601) <= $t)] | length')"
[ "${old:-1}" = 0 ] || am_fail "$old pod(s) of Deployment tollbooth have been running since before the new rate card was shipped"
am_ok "every pod of Deployment tollbooth is newer than the rate card"

# who asked for the restart? the restart annotation must have been written through the Argo CD API server
by_argo="$(kubectl -n "$NS" get deploy tollbooth -o json --show-managed-fields | jq -r '
  [.metadata.managedFields[] | select(.manager == "argocd-server") | select(.fieldsV1 | tostring | test("restartedAt"))] | length')"
[ "${by_argo:-0}" -ge 1 ] || am_fail "The pods were replaced, but not through an Argo CD resource action on the Deployment"
am_ok "the restart was triggered through Argo CD"

am_require_app_at_head "$APP" tollbooth
[ "$(am_ready_replicas tollbooth "$NS")" = 2 ] || am_fail "Deployment tollbooth has $(am_ready_replicas tollbooth "$NS") ready pods (expected 2)"
am_ok "Deployment tollbooth has 2 ready pods"

body="$(am_http http://tollbooth.tollbooth "$NS")" || am_fail "Service tollbooth in namespace $NS does not answer"
[ "$body" = "tollbooth rates 2025-Q4" ] || am_fail "Service tollbooth answers '$body'"
am_pass "tollbooth serves the new rate card after an Argo CD restart"

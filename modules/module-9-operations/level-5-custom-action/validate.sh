#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=ferry-booking NS=ferry KEY='ferry.argomissions.io/maintenance'
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

actions="$(am_argocd app actions list "$APP" --kind Deployment --resource-name ferry-booking -o json 2>/dev/null || echo '[]')"
state() { echo "$actions" | jq -r --arg a "$1" '[.[] | select(.Action == $a)] | if length == 0 then "missing" elif .[0].Disabled then "disabled" else "enabled" end'; }
[ "$(state maintenance-on)" != missing ] && [ "$(state maintenance-off)" != missing ] \
  || am_fail "Argo CD offers no maintenance actions for Deployment ferry-booking (actions: $(echo "$actions" | jq -r '[.[].Action] | join(", ")'))"
[ "$(state restart)" != missing ] \
  || am_fail "The built-in action 'restart' of Deployment ferry-booking disappeared: on-call still needs it"
am_ok "Argo CD offers maintenance-on, maintenance-off and still restart"

val="$(kubectl -n "$NS" get deploy ferry-booking -o json | jq -r --arg k "$KEY" '.metadata.annotations[$k] // ""')"
[ "$val" = on ] || am_fail "Deployment ferry-booking is not in maintenance mode (annotation $KEY is '${val:-unset}')"
by_argo="$(kubectl -n "$NS" get deploy ferry-booking -o json --show-managed-fields | jq -r '
  [.metadata.managedFields[] | select(.manager == "argocd-server") | select(.fieldsV1 | tostring | contains("maintenance"))] | length')"
[ "${by_argo:-0}" -ge 1 ] || am_fail "The maintenance annotation was not written through an Argo CD action"
am_ok "maintenance mode is on, switched on through Argo CD"

[ "$(state maintenance-on)" = disabled ] || am_fail "While maintenance is on, 'maintenance-on' should be disabled (it is $(state maintenance-on))"
[ "$(state maintenance-off)" = enabled ] || am_fail "While maintenance is on, 'maintenance-off' should be enabled (it is $(state maintenance-off))"
[ "$(state restart)" = enabled ] || am_fail "The built-in action 'restart' is $(state restart)"
am_ok "the actions follow the state of the Deployment"

# the annotation is operational state: not in Git
tmp="$AM_TMP/ferry"; am_repo_checkout ferry-booking "$tmp"
! grep -rq 'maintenance' "$tmp/deploy" || am_fail "The maintenance annotation was committed to Git; it is meant to be operational state"
am_require_app_at_head "$APP" ferry-booking
am_pass "maintenance mode is a button now"

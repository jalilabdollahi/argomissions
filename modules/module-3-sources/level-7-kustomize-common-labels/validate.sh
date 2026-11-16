#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=ledger-api
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"
repo="$(am_app "$APP" '{.spec.source.repoURL}')"
[ "${repo%.git}" = "$(am_repo_url ledger-api | sed 's/\.git$//')" ] || am_fail "Application '$APP' reads from '$repo', not the ledger-api repo"
[ "$(am_app "$APP" '{.spec.destination.namespace}')" = ledger ] || am_fail "Application '$APP' no longer deploys to namespace ledger"

am_require_app_at_head "$APP" ledger-api

sel="$(kubectl -n ledger get deploy ledger-api -o json 2>/dev/null | jq -cS '.spec.selector.matchLabels // {}')"
[ "$sel" = '{"app":"ledger-api"}' ] \
  || am_fail "Deployment ledger-api has selector $sel (the original selector was {\"app\":\"ledger-api\"})"
am_ok "Deployment selector is still {app: ledger-api}"

tpl="$(kubectl -n ledger get deploy ledger-api -o json 2>/dev/null | jq -c '.spec.template.metadata.labels // {}')"
[ "$(echo "$tpl" | jq -r '.team // ""')" = ledger ] && [ "$(echo "$tpl" | jq -r '."cost-center" // ""')" = cc-4711 ] \
  || am_fail "the pod template of Deployment ledger-api does not carry team=ledger and cost-center=cc-4711 (labels: $tpl)"
am_ok "pods carry team=ledger and cost-center=cc-4711"

am_wait_rollout deploy/ledger-api ledger 90s
n="$(kubectl -n ledger get pods -l team=ledger,cost-center=cc-4711,app=ledger-api --field-selector=status.phase=Running -o name 2>/dev/null | wc -l | tr -d ' ')"
[ "$n" -ge 1 ] || am_fail "no running pod of ledger-api carries the new labels"
body="$(am_http http://ledger-api.ledger ledger)" || am_fail "Service ledger-api does not answer"
[ "$body" = "ledger-api v2.2" ] || am_fail "Service ledger-api answers '$body'"
am_pass "labels are rolled out without touching the selector"

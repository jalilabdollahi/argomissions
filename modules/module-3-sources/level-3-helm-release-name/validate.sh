#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=fleet-tracker
am_app_exists "$APP" || am_fail "Application '$APP' does not exist (it must stay, not be deleted)"
[ "$(am_app "$APP" '{.spec.source.path}')" = "chart" ] || am_fail "Application '$APP' no longer deploys the Helm chart"

am_require_app_at_head "$APP" fleet-tracker

kubectl -n fleet get svc tracker-api >/dev/null 2>&1 || am_fail "Service tracker-api does not exist in namespace fleet - other teams call it by that name"
kubectl -n fleet get deploy tracker-api >/dev/null 2>&1 || am_fail "Deployment tracker-api does not exist in namespace fleet"
# A pruned object can stay Terminating for a few seconds; only a leftover that does not go away counts.
for kind in svc deploy; do
  for _ in $(seq 1 15); do kubectl -n fleet get "$kind" fleet-tracker-api >/dev/null 2>&1 || break; sleep 2; done
  kubectl -n fleet get "$kind" fleet-tracker-api >/dev/null 2>&1 \
    && am_fail "A $kind named fleet-tracker-api still exists in namespace fleet"
done
am_ok "Objects are named tracker-api, and nothing else is left over"

tid="$(am_jsonpath deploy/tracker-api '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' fleet)"
case "$tid" in fleet-tracker:*) ;; *) am_fail "Deployment tracker-api is not managed by the Application '$APP'";; esac
[ "$(am_ready_replicas tracker-api fleet)" -ge 1 ] || am_fail "Deployment tracker-api has no ready pods"

body="$(am_http http://tracker-api.fleet fleet)" || am_fail "Service tracker-api in namespace fleet does not answer"
[ "$body" = "tracker-api v3 (helm chart)" ] || am_fail "Service tracker-api answers '$body' - that is not the chart's release"
am_pass "tracker-api is served by the chart, under the name other teams use"

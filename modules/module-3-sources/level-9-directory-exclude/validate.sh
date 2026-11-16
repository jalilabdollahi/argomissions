#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=collector
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

am_repo_checkout telemetry-agents "$AM_TMP/repo" || am_fail "cannot read the telemetry-agents repo"
ls "$AM_TMP"/repo/deploy/tests/fixture-*.yaml >/dev/null 2>&1 \
  || am_fail "the CI fixtures are gone from deploy/tests/ in Git; CI still needs them"
[ -f "$AM_TMP/repo/deploy/collector.yaml" ] || am_fail "deploy/collector.yaml is missing from the repo"
am_ok "fixture files are still in Git"

repo="$(am_app "$APP" '{.spec.source.repoURL}')"
[ "${repo%.git}" = "$(am_repo_url telemetry-agents | sed 's/\.git$//')" ] \
  || am_fail "Application '$APP' reads from '$repo', not the telemetry-agents repo"
path="$(am_app "$APP" '{.spec.source.path}')"
[ "${path%/}" = deploy ] || am_fail "Application '$APP' deploys path '${path:-<repo root>}'"
[ "$(am_app "$APP" '{.spec.destination.namespace}')" = telemetry ] || am_fail "Application '$APP' no longer deploys to telemetry"

am_require_app_at_head "$APP" telemetry-agents

junk="$( { kubectl -n telemetry get deploy,pods,svc,job,cronjob -o name 2>/dev/null || true; } | grep -c fixture || true)"
[ "$junk" = 0 ] || am_fail "namespace telemetry still contains $junk fixture-* object(s)"
am_ok "no fixture objects in namespace telemetry"

[ -n "$(am_jsonpath deploy/metrics-collector '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' telemetry)" ] \
  || am_fail "Deployment metrics-collector is missing or not managed by Argo CD"
[ "$(am_ready_replicas metrics-collector telemetry)" -ge 1 ] || am_fail "Deployment metrics-collector has no ready pods"
body="$(am_http http://metrics-collector.telemetry telemetry)" || am_fail "Service metrics-collector does not answer"
[ "$body" = "metrics-collector v5.0" ] || am_fail "Service metrics-collector answers '$body'"
am_pass "collector runs without test fixtures"

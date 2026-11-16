#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=notify
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

# Git must still use the library chart through a file:// dependency that resolves
am_repo_checkout notify-platform "$AM_TMP/repo" || am_fail "cannot read the notify-platform repo"
chart="$AM_TMP/repo/charts/notify"
dep="$(am_yaml_get "$chart/Chart.yaml" dependencies.0)"
[ "$(echo "$dep" | jq -r '.name // ""')" = notify-common ] \
  || am_fail "chart notify no longer depends on notify-common; the shared templates must stay in the library chart"
repo="$(echo "$dep" | jq -r '.repository // ""')"
case "$repo" in file://*) ;; *) am_fail "the notify-common dependency is not a file:// dependency (repository: '${repo:-<empty>}')" ;; esac
target="$chart/${repo#file://}"
[ -f "$target/Chart.yaml" ] || am_fail "dependency repository '$repo' does not point at a chart directory in the repo"
[ "$(am_yaml_get "$target/Chart.yaml" name | jq -r .)" = notify-common ] \
  || am_fail "dependency repository '$repo' points at a chart that is not notify-common"
grep -rq 'define "notify-common.labels"' "$chart/templates" 2>/dev/null \
  && am_fail "the shared helpers were copied into chart notify instead of used from notify-common"
am_ok "chart notify uses the notify-common library chart via $repo"

src="$(am_app "$APP" '{.spec.source.repoURL}')"
[ "${src%.git}" = "$(am_repo_url notify-platform | sed 's/\.git$//')" ] || am_fail "Application '$APP' reads from '$src', not notify-platform"
[ "$(am_app "$APP" '{.spec.source.path}')" = charts/notify ] || am_fail "Application '$APP' no longer deploys charts/notify"

am_require_app_at_head "$APP" notify-platform

[ -n "$(am_jsonpath deploy/notify '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' notifications)" ] \
  || am_fail "Deployment notify is missing or not managed by Argo CD"
[ "$(am_ready_replicas notify notifications)" -ge 2 ] || am_fail "Deployment notify has fewer than 2 ready pods"
body="$(am_http http://notify.notifications notifications)" || am_fail "Service notify does not answer"
[ "$body" = "notify v4.7 (email)" ] || am_fail "Service notify answers '$body'"
am_pass "notify renders with its library chart and runs"

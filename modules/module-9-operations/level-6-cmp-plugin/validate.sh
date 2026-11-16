#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=label-printer
NS=labels-print

am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"
am_require_app_at_head "$APP" label-printer
am_require_synced_by_argo "$APP" label-printer

st="$(am_app "$APP" '{.status.sourceType}')"
[ "$st" = Plugin ] || am_fail "Application '$APP' is rendered as '${st:-unknown}', not by the team's config management plugin"
am_ok "Application '$APP' is rendered by a config management plugin"

# The service definition must still be the app.conf in Git, not hand-written manifests.
am_repo_checkout label-printer "$AM_TMP/git" >/dev/null 2>&1 || am_fail "cannot clone label-printer"
[ -f "$AM_TMP/git/deploy/app.conf" ] || am_fail "deploy/app.conf is gone from the repo: the service is no longer described by it"
if ls "$AM_TMP/git/deploy" | grep -qE '\.(ya?ml|json)$'; then
  am_fail "The repo now carries hand-written manifests next to app.conf"
fi

tracking="$(am_jsonpath deploy/label-printer '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' "$NS")"
[ -n "$tracking" ] || am_fail "Deployment $NS/label-printer does not exist or is not managed by Argo CD"
[ "$(am_ready_replicas label-printer "$NS")" -ge 2 ] || am_fail "Deployment label-printer in namespace $NS has fewer than 2 ready pods"
am_ok "Deployment label-printer has 2 ready pods, managed by Argo CD"

body="$(am_http http://label-printer.$NS "$NS")" || am_fail "Service label-printer in namespace $NS does not answer"
[ "$body" = "label-printer v2.1" ] || am_fail "Service label-printer answers '$body'"
am_pass "label-printer is rendered by its plugin and live"

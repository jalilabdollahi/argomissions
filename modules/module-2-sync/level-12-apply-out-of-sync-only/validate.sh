#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=region-configs
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

am_require_app_at_head "$APP" region-configs
head="$(am_repo_head region-configs)"
[ "$(am_app "$APP" '{.status.operationState.phase}')" = Succeeded ] \
  && [ "$(am_app "$APP" '{.status.operationState.syncResult.revision}')" = "$head" ] \
  || am_fail "No sync of '$APP' has completed at ${head:0:7}"

body="$(am_http http://edge-banner.regions regions)" || am_fail "Service edge-banner in namespace regions does not answer"
[ "$body" = "edge-banner r42" ] || am_fail "Service edge-banner answers '$body'"
tpl="$(am_jsonpath cm/region-eu-west '{.data.banner-template}' regions)"
[ "$tpl" = spring ] || am_fail "ConfigMap region-eu-west has banner-template '$tpl'"
am_ok "Release r42 is live"

count="$(am_jsonpath cm/visit-counter '{.data.count}' regions)"
[ "$count" = 4821 ] || am_fail "visit-counter holds '$count': the analytics controller's 4821 visits were overwritten by the sync"
am_ok "visit-counter still holds 4821, untouched by the release"

opts="$(am_app "$APP" '{.spec.syncPolicy.syncOptions}')"
echo "$opts" | grep -q 'ApplyOutOfSyncOnly=true' \
  || am_fail "Application '$APP' re-applies every object on each sync; the next release will overwrite the counter again"
am_pass "r42 is deployed, visit-counter was spared and the Application only applies what changed"

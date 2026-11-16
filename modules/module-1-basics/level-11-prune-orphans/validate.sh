#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=media
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

if kubectl -n media-prod get deploy legacy-worker >/dev/null 2>&1; then
  am_fail "Deployment legacy-worker still exists in namespace media-prod"
fi
am_ok "legacy-worker is gone"

am_require_app_at_head "$APP" media

want="$(am_app "$APP" '{.metadata.annotations.argomissions\.io/baseline-web-uid}')"
have="$(am_jsonpath deploy/media-web '{.metadata.uid}' media-prod)"
[ -n "$have" ] || am_fail "Deployment media-web does not exist in namespace media-prod"
[ -z "$want" ] || [ "$want" = "$have" ] || am_fail "Deployment media-web was deleted and recreated; it must keep running untouched"
am_ok "Deployment media-web is the same object as before"

am_repo_checkout media "$AM_TMP/repo" || am_fail "cannot clone the media repo"
am_yaml_docs_json "$AM_TMP/repo/deploy" | jq -e '[.[] | select(.metadata.name=="legacy-worker")] | length == 0' >/dev/null \
  || am_fail "The worker is back in the repo"

body="$(am_http http://media-web.media-prod media-prod)" || am_fail "Service media-web in namespace media-prod does not answer"
[ "$body" = "media v4.0" ] || am_fail "Service media-web answers '$body'"
am_pass "legacy-worker is retired and media is clean"

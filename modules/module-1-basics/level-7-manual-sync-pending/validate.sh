#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=search-api
am_require_app_at_head "$APP" search-api

head="$(am_repo_head search-api)"
synced="$(am_app "$APP" '{.status.operationState.syncResult.revision}')"
[ "$synced" = "$head" ] || am_fail "The last sync of '$APP' deployed ${synced:0:7}, but main is at ${head:0:7}: the release was never shipped through Argo CD"
am_ok "The latest release was shipped through an Argo CD sync"

[ "$(am_ready_replicas search-api search)" -ge 1 ] || am_fail "Deployment search-api in namespace search has no ready pod"
body="$(am_http http://search-api.search search)" || am_fail "Service search-api in namespace search does not answer"
[ "$body" = "search-api v2.3" ] || am_fail "Service search-api answers '$body'"
am_pass "search-api v2.3 is live"

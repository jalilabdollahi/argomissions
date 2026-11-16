#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=statement-api
PROJECT=billing-core

am_app_exists "$APP" || am_fail "Application '$APP' does not exist"
am_require_app_at_head "$APP" statement-api
am_require_synced_by_argo "$APP" statement-api

body="$(am_http http://statement-api.statements statements)" || am_fail "Service statement-api in namespace statements does not answer"
[ "$body" = "statement-api v1.4.1" ] || am_fail "Service statement-api answers '$body', not the fixed version"
am_ok "The fixed version is live"

deny="$(kubectl -n argocd get appproject "$PROJECT" -o json | jq '[.spec.syncWindows[]? | select(.kind=="deny")] | length')"
[ "${deny:-0}" -ge 1 ] || am_fail "Project $PROJECT has no deny sync window any more - the freeze is gone"
am_ok "Project $PROJECT still has a deny sync window"

am_argocd app get "$APP" >"$AM_TMP/get.txt" 2>&1
if grep -q "SyncWindow: *Sync Denied" "$AM_TMP/get.txt"; then
  am_fail "A manual sync of '$APP' is still blocked by a sync window - the next urgent fix would hit the same wall" "$AM_TMP/get.txt"
fi
am_ok "A manual sync of '$APP' is not blocked"
am_pass "The urgent fix went out and the freeze is still in place"

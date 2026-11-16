#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=metrics-gw
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

auto="$(am_app_json "$APP" | jq -c '.spec.syncPolicy.automated // empty')"
[ -n "$auto" ] || am_fail "Application '$APP' has no automated sync policy: a push to main still waits for a person to press Sync"
am_ok "Application '$APP' syncs automatically"

repo="$(am_app "$APP" '{.spec.source.repoURL}')"
[ "${repo%.git}" = "$(am_repo_url metrics-gw | sed 's/\.git$//')" ] || am_fail "Application '$APP' no longer reads the metrics-gw repo"

# the automated sync must have caught up with the head of main without anybody pressing Sync afterwards
am_wait 60 bash -c "[ \"\$(kubectl -n argocd get application $APP -o jsonpath='{.status.sync.revision}')\" = \"$(am_repo_head metrics-gw)\" ]" || true
am_require_app_at_head "$APP" metrics-gw

am_wait_rollout deploy/metrics-gw metrics 60s
body="$(am_http http://metrics-gw.metrics metrics)" || am_fail "Service metrics-gw in namespace metrics does not answer"
[ "$body" = "metrics-gw v1.3" ] || am_fail "Service metrics-gw answers '$body', main has moved on"
am_pass "metrics-gw deploys itself from main"

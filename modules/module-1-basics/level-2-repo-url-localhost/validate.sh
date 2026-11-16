#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=orders
am_app_exists "$APP" || am_fail "No Application named '$APP' in namespace argocd"

repo="$(am_app "$APP" '{.spec.source.repoURL}')"
[ "${repo%.git}" = "$(am_repo_url orders | sed 's/\.git$//')" ] \
  || am_fail "Application '$APP' reads from '$repo', which the Argo CD repo-server cannot use to fetch the orders repo"
am_ok "Application '$APP' uses a repo URL Argo CD can reach"

am_require_app_at_head "$APP" orders

body="$(am_http http://orders.orders orders)" || am_fail "Service orders in namespace orders does not answer"
[ "$body" = "orders v1.4" ] || am_fail "Service orders answers '$body'"
am_pass "orders is live from the repo Argo CD can reach"

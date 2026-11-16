#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=ledger
am_app_exists "$APP" || am_fail "No Application named '$APP' in namespace argocd"

opts="$(am_app "$APP" '{.spec.syncPolicy.syncOptions}')"
echo "$opts" | grep -q 'CreateNamespace=true' \
  || am_fail "Application '$APP' cannot deploy to a fresh cluster on its own: it relies on the namespace already being there"
am_ok "Application '$APP' creates its namespace when needed"

am_require_app_at_head "$APP" ledger

kubectl get namespace ledger >/dev/null 2>&1 || am_fail "Namespace ledger does not exist"
[ "$(am_ready_replicas ledger ledger)" -ge 1 ] || am_fail "Deployment ledger in namespace ledger has no ready pod"

body="$(am_http http://ledger.ledger ledger)" || am_fail "Service ledger in namespace ledger does not answer"
[ "$body" = "ledger v1.0" ] || am_fail "Service ledger answers '$body'"
am_pass "ledger is live and brings its own namespace"

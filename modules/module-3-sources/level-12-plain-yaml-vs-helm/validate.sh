#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=docs-portal
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"
src="$(am_app "$APP" '{.spec.source.repoURL}')"
[ "${src%.git}" = "$(am_repo_url docs-portal | sed 's/\.git$//')" ] || am_fail "Application '$APP' reads from '$src', not the docs-portal repo"
[ "$(am_app "$APP" '{.spec.source.path}')" = deploy ] || am_fail "Application '$APP' no longer deploys the deploy/ folder"
[ "$(am_app "$APP" '{.spec.destination.namespace}')" = docs ] || am_fail "Application '$APP' no longer deploys to namespace docs"

am_require_app_at_head "$APP" docs-portal

tool="$(am_app "$APP" '{.status.sourceType}')"
[ "$tool" = Directory ] || am_fail "Argo CD renders deploy/ with the '${tool:-unknown}' tool; the folder holds plain manifests"
am_ok "deploy/ is rendered as plain manifests (source type Directory)"

for k in deploy svc; do
  [ -n "$(am_jsonpath "$k/docs-portal" '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' docs)" ] \
    || am_fail "$k/docs-portal in namespace docs is missing or not managed by Argo CD"
done
[ "$(am_ready_replicas docs-portal docs)" -ge 2 ] || am_fail "Deployment docs-portal has fewer than 2 ready pods"
body="$(am_http http://docs-portal.docs docs)" || am_fail "Service docs-portal does not answer"
[ "$body" = "docs-portal v1.8" ] || am_fail "Service docs-portal answers '$body'"
am_pass "docs-portal is deployed as plain manifests"

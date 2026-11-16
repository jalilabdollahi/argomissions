#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=status-page
am_app_exists "$APP" || am_fail "No Application named '$APP' in namespace argocd (argocd app list is empty)"

repo="$(am_app "$APP" '{.spec.source.repoURL}')"
path="$(am_app "$APP" '{.spec.source.path}')"
dest_ns="$(am_app "$APP" '{.spec.destination.namespace}')"
[ "${repo%.git}" = "$(am_repo_url status-page | sed 's/\.git$//')" ] \
  || am_fail "Application '$APP' reads from '$repo', not the status-page repo as Argo CD sees it"
[ "${path%/}" = "deploy" ] || am_fail "Application '$APP' deploys path '${path:-<repo root>}', the manifests are in deploy/"
[ "$dest_ns" = "status" ] || am_fail "Application '$APP' deploys to namespace '${dest_ns:-<none>}', not 'status'"
am_ok "Application '$APP' points at status-page/deploy → namespace status"

am_require_app_at_head "$APP" status-page

tracking="$(am_jsonpath deploy/status-page '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' status)"
[ -n "$tracking" ] || am_fail "Deployment status/status-page is not managed by Argo CD"
[ "$(am_ready_replicas status-page status)" -ge 2 ] || am_fail "Deployment status/status-page has fewer than 2 ready pods"
am_ok "Deployment status-page has 2 ready pods, managed by Argo CD"

body="$(am_http http://status-page.status status)" || am_fail "Service status-page in namespace status does not answer"
[ "$body" = "status-page v1.0" ] || am_fail "Service status-page answers '$body'"
am_pass "status-page is live and owned by Argo CD"

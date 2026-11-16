#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=inventory
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

# the repo layout must stay: manifests live in deploy/web and deploy/db
am_repo_checkout inventory-stack "$AM_TMP/repo" || am_fail "cannot read the inventory-stack repo"
[ -f "$AM_TMP/repo/deploy/web/deployment.yaml" ] && [ -f "$AM_TMP/repo/deploy/db/deployment.yaml" ] \
  || am_fail "the repo layout (deploy/web and deploy/db) was changed; the team wants to keep it"
am_ok "repo layout deploy/web + deploy/db is intact"

repo="$(am_app "$APP" '{.spec.source.repoURL}')"
[ "${repo%.git}" = "$(am_repo_url inventory-stack | sed 's/\.git$//')" ] \
  || am_fail "Application '$APP' reads from '$repo', not the inventory-stack repo"
[ "$(am_app "$APP" '{.spec.destination.namespace}')" = inventory ] \
  || am_fail "Application '$APP' no longer deploys to namespace inventory"
path="$(am_app "$APP" '{.spec.source.path}')"
[ "${path%/}" = deploy ] || am_fail "Application '$APP' deploys path '${path:-<repo root>}'; both tiers live below deploy/"

am_require_app_at_head "$APP" inventory-stack

for d in stock-web stock-db; do
  [ -n "$(am_jsonpath "deploy/$d" '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' inventory)" ] \
    || am_fail "Deployment $d in namespace inventory is missing or not managed by Argo CD"
  [ "$(am_ready_replicas "$d" inventory)" -ge 1 ] || am_fail "Deployment $d has no ready pods"
  kubectl -n inventory get svc "$d" >/dev/null 2>&1 || am_fail "Service $d does not exist in namespace inventory"
done
am_ok "both tiers are deployed and owned by Argo CD"

body="$(am_http http://stock-web.inventory inventory)" || am_fail "Service stock-web does not answer"
[ "$body" = "stock-web v3.1" ] || am_fail "Service stock-web answers '$body'"
am_pass "inventory runs both tiers from Git"

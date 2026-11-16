#!/bin/bash
set -uo pipefail
source "$AM_LIB"

ROOT=lighthouse-bootstrap
am_app_exists "$ROOT" || am_fail "There is no Application named '$ROOT' in namespace argocd"
repo="$(am_app "$ROOT" '{.spec.source.repoURL}')"
[ "${repo%.git}" = "$(am_repo_url lighthouse-gitops | sed 's/\.git$//')" ] \
  || am_fail "Application '$ROOT' reads from '$repo', not from the lighthouse-gitops repo as Argo CD sees it"
[ "$(am_app "$ROOT" '{.spec.destination.namespace}')" = argocd ] || am_fail "Application '$ROOT' deploys to namespace '$(am_app "$ROOT" '{.spec.destination.namespace}')', where Argo CD does not look for Applications"
am_require_app_at_head "$ROOT" lighthouse-gitops
am_require_synced_by_argo "$ROOT" lighthouse-gitops

# the root manages Applications and AppProjects, nothing else
kinds="$(am_app_json "$ROOT" | jq -r '[.status.resources[]?.kind] | unique | join(",")')"
[ "$kinds" = "AppProject,Application" ] || am_fail "The resources of '$ROOT' are of kinds [$kinds]; expected exactly AppProject and Application"

for p in infra services; do
  tid="$(kubectl -n argocd get appproject "$p" -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null)"
  [ "$tid" = "$ROOT:argoproj.io/AppProject:argocd/$p" ] || am_fail "AppProject '$p' does not exist or is not managed by '$ROOT'"
done
am_ok "AppProjects infra and services are managed by $ROOT"

for a in lighthouse-cache lighthouse-gateway lighthouse-catalog; do
  am_app_exists "$a" || am_fail "Application '$a' does not exist"
  tid="$(am_app "$a" '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}')"
  [ "$tid" = "$ROOT:argoproj.io/Application:argocd/$a" ] || am_fail "Application '$a' is not managed by '$ROOT'"
  am_require_app_at_head "$a" lighthouse-gitops
done
if am_app_exists lighthouse-billing-legacy || kubectl get namespace lighthouse-legacy >/dev/null 2>&1; then
  am_fail "The retired component lighthouse-billing-legacy is deployed"
fi
am_ok "The three components are Synced and Healthy, the retired one is not deployed"

for spec in "lighthouse-cache lighthouse-infra v7.2" "lighthouse-gateway lighthouse-edge v1.4" "lighthouse-catalog lighthouse-core v5.0"; do
  set -- $spec
  body="$(am_http "http://$1.$2" "$2")" || am_fail "Service $1 in namespace $2 does not answer"
  [ "$body" = "$1 $3" ] || am_fail "Service $1 answers '$body'"
done
am_pass "The platform is rebuilt from Git, owned by lighthouse-bootstrap"

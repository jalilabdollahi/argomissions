#!/bin/bash
set -uo pipefail
source "$AM_LIB"

am_require_app_at_head meterhub-env-prod meterhub-gitops
am_require_synced_by_argo meterhub-env-prod meterhub-gitops
# the staging root only has to be in order: a change under envs/prod/ does not have to be picked up by it
[ "$(am_app_sync meterhub-env-staging)" = Synced ] && [ "$(am_app_health meterhub-env-staging)" = Healthy ] \
  || am_fail "Application 'meterhub-env-staging' is $(am_app_sync meterhub-env-staging)/$(am_app_health meterhub-env-staging)"
for env in staging prod; do
  tid="$(am_app "meterhub-$env" '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}')"
  [ "$tid" = "meterhub-env-$env:argoproj.io/Application:argocd/meterhub-$env" ] \
    || am_fail "Application 'meterhub-$env' is not managed by 'meterhub-env-$env'"
done

# production: pinned to the release
svc="$(git ls-remote "http://$AM_GIT_USER:$AM_GIT_PASS@localhost:$AM_GIT_PORT/$AM_ORG/meterhub-service.git" 'refs/tags/v1.2.0' | awk '{print $1}')"
[ -n "$svc" ] || am_fail "Tag v1.2.0 of meterhub-service is gone"
prod_rev="$(am_app meterhub-prod '{.spec.source.targetRevision}')"
case "$prod_rev" in
  v1.2.0|refs/tags/v1.2.0) ;;
  main|HEAD|refs/heads/main) am_fail "meterhub-prod follows '$prod_rev': production moves with every merge, not with releases" ;;
  *) am_fail "meterhub-prod tracks '$prod_rev', not the release tag v1.2.0" ;;
esac
[ "$(am_app_sync meterhub-prod)" = Synced ] || am_fail "meterhub-prod is $(am_app_sync meterhub-prod), expected Synced"
[ "$(am_app_health meterhub-prod)" = Healthy ] || am_fail "meterhub-prod health is $(am_app_health meterhub-prod)"
[ "$(am_app_rev meterhub-prod)" = "$svc" ] || am_fail "meterhub-prod is deployed from $(am_app_rev meterhub-prod | cut -c1-7), not from the commit of v1.2.0 (${svc:0:7})"
am_ok "meterhub-prod is Synced and Healthy at tag v1.2.0 (${svc:0:7}), through its root"

# staging: still follows main
main_head="$(am_repo_head meterhub-service)"
stg_rev="$(am_app meterhub-staging '{.spec.source.targetRevision}')"
case "$stg_rev" in main|HEAD|refs/heads/main) ;; *) am_fail "meterhub-staging tracks '$stg_rev': staging is supposed to follow main" ;; esac
[ "$(am_app_sync meterhub-staging)" = Synced ] && [ "$(am_app_health meterhub-staging)" = Healthy ] \
  || am_fail "meterhub-staging is $(am_app_sync meterhub-staging)/$(am_app_health meterhub-staging)"
[ "$(am_app_rev meterhub-staging)" = "$main_head" ] || am_fail "meterhub-staging is not at the head of main of meterhub-service"
am_ok "meterhub-staging follows main (${main_head:0:7})"

body="$(am_http http://meterhub.meterhub-prod meterhub-prod)" || am_fail "Service meterhub in namespace meterhub-prod does not answer"
[ "$body" = "meterhub v1.2.0" ] || am_fail "Service meterhub in meterhub-prod answers '$body'"
body="$(am_http http://meterhub.meterhub-staging meterhub-staging)" || am_fail "Service meterhub in namespace meterhub-staging does not answer"
[ "$body" = "meterhub v1.3.0-rc1" ] || am_fail "Service meterhub in meterhub-staging answers '$body'"
am_pass "Production runs v1.2.0, staging runs main"

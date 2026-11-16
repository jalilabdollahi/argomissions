#!/bin/bash
set -uo pipefail
source "$AM_LIB"

am_require_app_at_head courier-fleet courier-fleet
am_require_synced_by_argo courier-fleet courier-fleet
[ "$(am_app courier-fleet '{.spec.syncPolicy.automated.selfHeal}')" = true ] \
  || am_fail "Application 'courier-fleet' no longer self-heals: the platform is not protected against hand edits any more"
for a in courier-routing courier-tracking; do
  tid="$(am_app "$a" '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}')"
  [ "$tid" = "courier-fleet:argoproj.io/Application:argocd/$a" ] || am_fail "Application '$a' is not managed by 'courier-fleet'"
done

hotfix="$(am_repo_head courier-services hotfix-routing)"
[ -n "$hotfix" ] || am_fail "Branch hotfix-routing of courier-services is gone"
rev="$(am_app courier-routing '{.spec.source.targetRevision}')"
case "$rev" in
  hotfix-routing|refs/heads/hotfix-routing|"$hotfix") ;;
  main|HEAD|refs/heads/main) am_fail "courier-routing follows '$rev', not the hotfix" ;;
  *) am_fail "courier-routing tracks '$rev', not the hotfix" ;;
esac
[ "$(am_app_sync courier-routing)" = Synced ] && [ "$(am_app_health courier-routing)" = Healthy ] \
  || am_fail "courier-routing is $(am_app_sync courier-routing)/$(am_app_health courier-routing)"
[ "$(am_app_rev courier-routing)" = "$hotfix" ] || am_fail "courier-routing is deployed from $(am_app_rev courier-routing | cut -c1-7), not from the head of hotfix-routing (${hotfix:0:7})"
am_ok "courier-routing is Synced and Healthy at hotfix-routing (${hotfix:0:7})"

main_head="$(am_repo_head courier-services main)"
web_rev="$(am_app courier-tracking '{.spec.source.targetRevision}')"
case "$web_rev" in main|HEAD|refs/heads/main) ;; *) am_fail "courier-tracking tracks '$web_rev': it was not supposed to change" ;; esac
[ "$(am_app_sync courier-tracking)" = Synced ] && [ "$(am_app_health courier-tracking)" = Healthy ] && [ "$(am_app_rev courier-tracking)" = "$main_head" ] \
  || am_fail "courier-tracking is not Synced and Healthy at the head of main"
am_ok "courier-tracking still follows main"

body="$(am_http http://courier-routing.courier-routing courier-routing)" || am_fail "Service courier-routing in namespace courier-routing does not answer"
[ "$body" = "courier-routing v2.4.1" ] || am_fail "Service courier-routing answers '$body'"
body="$(am_http http://courier-tracking.courier-tracking courier-tracking)" || am_fail "Service courier-tracking in namespace courier-tracking does not answer"
[ "$body" = "courier-tracking v1.9.0" ] || am_fail "Service courier-tracking answers '$body'"
am_pass "The hotfix is live and the platform stays in charge of it"

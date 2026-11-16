#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=ticket-desk
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

# Git is the truth: the relabelled selector must still be what Git says
am_repo_checkout ticket-desk "$AM_TMP/git" || am_fail "cannot clone repo ticket-desk"
git_sel="$(am_yaml_docs_json "$AM_TMP/git/deploy" | jq -c '[.[] | select(.kind=="Deployment" and .metadata.name=="ticket-desk")][0].spec.selector.matchLabels // {}')"
[ "$(echo "$git_sel" | jq 'has("app.kubernetes.io/name")')" = true ] \
  || am_fail "Git no longer carries the new selector for Deployment ticket-desk (selector in Git: $git_sel)"
am_ok "Git carries the new selector $git_sel"

am_require_app_at_head "$APP" ticket-desk

live_sel="$(kubectl -n helpdesk get deploy ticket-desk -o json 2>/dev/null | jq -c '.spec.selector.matchLabels // {}')"
[ "$(echo "$live_sel" | jq 'has("app.kubernetes.io/name")')" = true ] \
  || am_fail "The live Deployment ticket-desk still selects pods with $live_sel"
am_ok "Live Deployment uses selector $live_sel"

[ "$(am_ready_replicas ticket-desk helpdesk)" -ge 2 ] || am_fail "Deployment helpdesk/ticket-desk has fewer than 2 ready pods"
[ "$(am_endpoints_count ticket-desk helpdesk)" -ge 2 ] || am_fail "Service ticket-desk has fewer than 2 ready endpoints"
body="$(am_http http://ticket-desk.helpdesk helpdesk)" || am_fail "Service ticket-desk in namespace helpdesk does not answer"
[ "$body" = "ticket-desk v1.1" ] || am_fail "Service ticket-desk answers '$body'"
am_pass "ticket-desk v1.1 is live with the new selector, owned by Argo CD"

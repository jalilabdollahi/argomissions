#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=invoices
am_app_exists "$APP" || am_fail "No Application named '$APP' in namespace argocd"

rev="$(am_app "$APP" '{.spec.source.targetRevision}')"
case "$rev" in
  main|HEAD|refs/heads/main) am_ok "Application '$APP' tracks '$rev'" ;;
  *) am_fail "Application '$APP' tracks '${rev:-<empty>}', which is not the branch the team works on" ;;
esac

branches="$(git ls-remote --heads "$(_am_push_url invoices)" 2>/dev/null | awk '{print $2}')"
echo "$branches" | grep -qx 'refs/heads/main' || am_fail "The invoices repo has no main branch any more"
echo "$branches" | grep -qx 'refs/heads/master' && am_fail "The invoices repo has a master branch again: the rename must stay"
am_ok "The repo still has only the main branch"

am_require_app_at_head "$APP" invoices main

body="$(am_http http://invoices.invoices invoices)" || am_fail "Service invoices in namespace invoices does not answer"
[ "$body" = "invoices v3.1" ] || am_fail "Service invoices answers '$body'"
am_pass "invoices is live from main"

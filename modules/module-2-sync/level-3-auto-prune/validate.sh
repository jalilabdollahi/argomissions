#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=gallery-web
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

am_repo_checkout gallery-web "$AM_TMP/repo" || am_fail "cannot clone the gallery-web repo"
docs="$(am_yaml_docs_json "$AM_TMP/repo")"
[ "$(echo "$docs" | jq '[.[] | select(.kind=="Service" and .metadata.name=="gallery-classic")] | length')" = 0 ] \
  || am_fail "Service gallery-classic is back in Git: the team decided to retire it"
am_ok "Git no longer describes Service gallery-classic"

am_app_json "$APP" | jq -e '.spec.syncPolicy.automated != null' >/dev/null \
  || am_fail "Application '$APP' is not automated any more"
[ "$(am_app_json "$APP" | jq -r '.spec.syncPolicy.automated.prune // false')" = true ] \
  || am_fail "Application '$APP' does not clean up objects that were removed from Git: the next retired manifest will be left running too"
am_ok "Application '$APP' prunes by itself"

am_wait 60 bash -c '! kubectl -n gallery get svc gallery-classic' \
  || am_fail "Service gallery-classic is still running in namespace gallery although Git removed it"
am_ok "the retired Service is gone"

am_require_app_at_head "$APP" gallery-web
am_wait_rollout deploy/gallery-web gallery 60s
body="$(am_http http://gallery-web.gallery gallery)" || am_fail "Service gallery-web in namespace gallery does not answer"
[ "$body" = "gallery-web v3.1" ] || am_fail "Service gallery-web answers '$body'"
am_pass "gallery-web is tidy: what Git removes, Argo CD removes"

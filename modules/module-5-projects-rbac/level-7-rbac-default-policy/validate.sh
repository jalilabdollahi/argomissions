#!/bin/bash
set -uo pipefail
source "$AM_LIB"

# The CLI as another identity, with its own config file (the game's admin session stays untouched).
as_user() {
  local who="$1"; shift
  env -u ARGOCD_OPTS argocd "$@" --config "$AM_TMP/$who-cli" --plaintext
}
login() {
  as_user "$1" login "$AM_ARGOCD_ADDR" --username "$1" --password "$1-pw-4821" >/dev/null 2>"$AM_TMP/login.err" \
    || am_fail "Cannot log in as '$1' (password $1-pw-4821)" "$AM_TMP/login.err"
}
# expect WHO yes|no VERB RESOURCE OBJECT  (permission changes take a few seconds to be picked up)
expect() {
  local who="$1" want="$2" got="" i
  shift 2
  for i in 1 2 3 4 5 6; do
    got="$(as_user "$who" account can-i "$@" 2>/dev/null)"
    [ "$got" = "$want" ] && return 0
    sleep 2
  done
  return 1
}

am_app_exists claims-portal || am_fail "Application 'claims-portal' does not exist"
am_require_app_at_head claims-portal claims-portal

login bob
login alice

for check in "get applications default/claims-portal" "get projects default" "get clusters *"; do
  expect bob yes $check || am_fail "bob cannot '${check%% *}' ${check#* } - he should be able to look around"
done
am_ok "bob can look at applications, projects and clusters"

for check in "sync applications default/claims-portal" "delete applications default/claims-portal" \
             "update applications default/claims-portal" "create applications default/new-app" \
             "override applications default/claims-portal" "create projects new-project" "delete projects default"; do
  expect bob no $check || am_fail "bob is allowed to ${check%% *} ${check#* } - he must be read-only"
done
am_ok "bob is read-only"

for check in "delete applications default/claims-portal" "sync applications default/claims-portal" \
             "create applications default/new-app" "create projects new-project" "update clusters *"; do
  expect alice yes $check || am_fail "alice cannot '${check%% *}' ${check#* } - she must stay an administrator"
done
am_ok "alice is still an administrator"

am_pass "Defaults are read-only and the platform lead keeps admin rights"

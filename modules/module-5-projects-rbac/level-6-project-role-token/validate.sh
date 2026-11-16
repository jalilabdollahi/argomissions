#!/bin/bash
set -uo pipefail
source "$AM_LIB"

# The Argo CD CLI as a different identity: only the token, no session of the game's admin.
# (env -u: the game's ARGOCD_OPTS must not leak the admin config into this call)
as_token() {
  local tok="$1"; shift
  env -u ARGOCD_OPTS argocd "$@" --config "$AM_TMP/pipeline-cli" --plaintext \
    --server "$AM_ARGOCD_ADDR" --auth-token "$tok"
}

am_app_exists settle-api || am_fail "Application 'settle-api' does not exist"
am_require_app_at_head settle-api settle-api

tok="$(kubectl -n settle-ci get secret argocd-pipeline-token -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null | tr -d '\0')"
[ -n "$tok" ] || am_fail "Secret 'argocd-pipeline-token' (key 'token') in namespace settle-ci is missing or empty"

payload="$(printf '%s' "$tok" | cut -d. -f2 | tr '_-' '/+')"
while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="$payload="; done
claims="$(printf '%s' "$payload" | base64 -d 2>/dev/null | tr -d '\0')"
sub="$(printf '%s' "$claims" | jq -r '.sub // empty' 2>/dev/null)"
[ -n "$sub" ] || am_fail "The value in the pipeline Secret is not an Argo CD token (no JWT claims)"
[ "$sub" = "proj:settlements:deployer" ] \
  || am_fail "The token in the pipeline Secret belongs to '$sub', not to the project role 'deployer' of project 'settlements'"
am_ok "The Secret holds a token of project role settlements/deployer"

can() { as_token "$tok" account can-i "$@" 2>"$AM_TMP/can.err"; }
for check in "get applications settlements/settle-api" "sync applications settlements/settle-api"; do
  [ "$(can $check)" = yes ] || am_fail "The pipeline token is not allowed to '${check%% *}' Applications of project settlements (or is not accepted by Argo CD at all)" "$AM_TMP/can.err"
done
am_ok "The token may get and sync Applications of project settlements"

for check in "delete applications settlements/settle-api" "create applications settlements/settle-api" \
             "override applications settlements/settle-api" "update applications settlements/settle-api" \
             "sync applications default/settle-api" "get applications default/settle-api"; do
  [ "$(can $check)" = no ] || am_fail "The pipeline token is allowed to ${check%% *} ${check#* } - far more than a release needs"
done
am_ok "The token is refused everything beyond get and sync in its own project"

am_pass "The pipeline carries a least-privilege project token"

#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=rates-service
NS=fx-rates

am_require_app_at_head "$APP" rates-service
am_require_synced_by_argo "$APP" rates-service

# History must be intact (fix forward, never rewrite) and the good changes of later releases must survive.
am_repo_checkout rates-service "$AM_TMP/git" >/dev/null 2>&1 || am_fail "cannot clone rates-service"
subjects="$(git -C "$AM_TMP/git" log --format=%s)"
for s in "rates-service v1.0" "Bump rates-service to v1.1" "Align environment values with the staging config" \
         "Release v1.2: run two replicas" "Raise cache TTL to 600 seconds"; do
  grep -qxF "$s" <<<"$subjects" || am_fail "The Git history of rates-service lost a released commit ('$s'): history was rewritten"
done
am_ok "The commit history of rates-service is intact"

am_yaml_docs_json "$AM_TMP/git/deploy" >"$AM_TMP/docs.json"
env_of() { jq -r --arg n "$1" '[.[] | select(.kind=="Deployment")][0].spec.template.spec.containers[0].env[]? | select(.name==$n) | .value' "$AM_TMP/docs.json"; }
[ "$(env_of BASE_CURRENCY)" = EUR ] || am_fail "Git still sets BASE_CURRENCY to '$(env_of BASE_CURRENCY)'"
[ "$(env_of APP_VERSION)" = v1.2 ] || am_fail "Git no longer releases v1.2 (APP_VERSION is '$(env_of APP_VERSION)')"
[ "$(env_of CACHE_TTL)" = 600 ] || am_fail "The cache TTL change of the latest release is gone from Git (CACHE_TTL is '$(env_of CACHE_TTL)')"
repl="$(jq -r '[.[] | select(.kind=="Deployment")][0].spec.replicas' "$AM_TMP/docs.json")"
[ "$repl" = 2 ] || am_fail "Git runs $repl replica(s), the v1.2 release runs 2"
am_ok "Git keeps the v1.2 release and the TTL change, with the right currency"

[ "$(am_ready_replicas rates-service "$NS")" -ge 2 ] || am_fail "Deployment rates-service in namespace $NS has fewer than 2 ready pods"
body="$(am_http http://rates-service.$NS "$NS")" || am_fail "Service rates-service in namespace $NS does not answer"
[ "$body" = "fx-rates v1.2 currency=EUR source=ecb" ] || am_fail "Service rates-service answers '$body'"
am_pass "rates-service serves the right currency again, with history intact"

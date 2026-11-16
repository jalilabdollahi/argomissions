#!/bin/bash
set -uo pipefail
source "$AM_LIB"

# act as the bot with a throw-away CLI config: the game's own admin session is never touched
ci_argocd() { ARGOCD_OPTS="" command argocd --config "$AM_TMP/ci" --plaintext --server "$AM_ARGOCD_ADDR" "$@"; }
can() { [ "$(ci_argocd account can-i "$@" 2>/dev/null)" = yes ]; }

caps="$(kubectl -n argocd get cm argocd-cm -o jsonpath='{.data.accounts\.ci-bot}' 2>/dev/null)"
case "$caps" in *apiKey*login*|*login*apiKey*) ;; *) am_fail "The ci-bot account is no longer declared with its apiKey and login capabilities in argocd-cm";; esac
ci_argocd login "$AM_ARGOCD_ADDR" --username ci-bot --password ci-bot-pass-123 >"$AM_TMP/login.txt" 2>&1 \
  || am_fail "ci-bot cannot log in" "$AM_TMP/login.txt"
am_ok "ci-bot can log in"

am_wait 40 can sync applications 'shop/shop-web' \
  || am_fail "ci-bot is not allowed to sync applications in project 'shop' (the CI pipeline is still refused)"
can get applications 'shop/shop-web' || am_fail "ci-bot cannot read applications in project 'shop'"
am_ok "ci-bot may get and sync applications in project 'shop'"

for a in "sync applications people/hr-portal" "get applications people/hr-portal"; do
  # shellcheck disable=SC2086
  can $a && am_fail "ci-bot can reach another team's application ('$a')"
done
for a in "delete applications shop/shop-web" "update applications shop/shop-web" "create applications shop/shop-web" \
         "override applications shop/shop-web" "create projects shop" "update projects shop" "get clusters *" "get repositories *"; do
  # shellcheck disable=SC2086
  can $a && am_fail "ci-bot has more rights than a deploy pipeline needs ('$a' is allowed)"
done
am_ok "ci-bot cannot touch other projects, delete or edit applications, or manage Argo CD itself"

ci_argocd app list -o name >"$AM_TMP/list.txt" 2>&1 || am_fail "ci-bot cannot list applications" "$AM_TMP/list.txt"
grep -q 'shop-web' "$AM_TMP/list.txt" || am_fail "ci-bot does not see the shop-web application"
grep -q 'hr-portal' "$AM_TMP/list.txt" && am_fail "ci-bot can see the people project's hr-portal"
am_pass "ci-bot can deploy the shop, and only the shop"

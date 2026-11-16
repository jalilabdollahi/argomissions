#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=checkout
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

am_repo_checkout checkout "$AM_TMP/repo" || am_fail "cannot clone the checkout repo"
docs="$(am_yaml_docs_json "$AM_TMP/repo/deploy")"
git_replicas="$(echo "$docs" | jq -r '[.[] | select(.kind=="Deployment" and .metadata.name=="checkout")][0].spec.replicas // 1')"
[ "$git_replicas" = 3 ] || am_fail "The manifest on main asks for $git_replicas replica(s), not the 3 that production needs"
am_ok "Git asks for 3 replicas"

am_require_app_at_head "$APP" checkout

[ "$(am_jsonpath deploy/checkout '{.spec.replicas}' checkout)" = 3 ] || am_fail "Deployment checkout does not run with 3 replicas"
three_ready() { [ "$(am_ready_replicas checkout checkout)" = 3 ]; }
am_wait 60 three_ready || am_fail "Deployment checkout has $(am_ready_replicas checkout checkout) ready pods, expected 3"
am_ok "Deployment checkout has 3 ready replicas"

body="$(am_http http://checkout.checkout checkout)" || am_fail "Service checkout in namespace checkout does not answer"
[ "$body" = "checkout v5.2" ] || am_fail "Service checkout answers '$body'"
am_pass "checkout runs 3 replicas and Git agrees"

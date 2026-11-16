#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=search-suggest
am_app_exists "$APP" || am_fail "Application '$APP' does not exist (it must stay, not be deleted)"

am_require_app_at_head "$APP" search-suggest

json="$(am_app_json "$APP")"
has_obj="$(echo "$json" | jq -r '(.spec.source.helm.valuesObject // {}) | length')"
has_str="$(echo "$json" | jq -r '(.spec.source.helm.values // "") | length')"
[ "$has_obj" != 0 ] || [ "$has_str" != 0 ] \
  || am_fail "The Application carries no inline Helm values - the production settings are meant to live in the Application"
am_repo_checkout search-suggest "$AM_TMP/co" || am_fail "cannot clone search-suggest"
[ "$(am_yaml_get "$AM_TMP/co/chart/values.yaml" replicaCount)" = 1 ] \
  || am_fail "chart/values.yaml in Git was changed - the defaults must stay development defaults"

[ "$(am_jsonpath deploy/search-suggest '{.spec.replicas}' search)" = 3 ] \
  || am_fail "Deployment search-suggest has $(am_jsonpath deploy/search-suggest '{.spec.replicas}' search) replicas, production needs 3"
[ "$(am_ready_replicas search-suggest search)" = 3 ] || am_fail "Deployment search-suggest does not have 3 ready pods"
am_ok "Deployment search-suggest runs 3 replicas"

body="$(am_http http://search-suggest.search search)" || am_fail "Service search-suggest in namespace search does not answer"
[ "$body" = "search-suggest prod 4.1" ] || am_fail "Service search-suggest answers '$body'"
am_pass "search-suggest runs with the production values from the Application"

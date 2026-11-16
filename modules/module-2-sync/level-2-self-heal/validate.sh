#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=pricing-api
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"

am_repo_checkout pricing-api "$AM_TMP/repo" || am_fail "cannot clone the pricing-api repo"
docs="$(am_yaml_docs_json "$AM_TMP/repo/deploy")"
git_replicas="$(echo "$docs" | jq -r '[.[] | select(.kind=="Deployment")][0].spec.replicas // 1')"
git_discount="$(echo "$docs" | jq -r '[.[] | select(.kind=="ConfigMap" and .metadata.name=="pricing-rules")][0].data["max-discount-percent"] // ""')"
[ "$git_replicas" = 2 ] && [ "$git_discount" = 5 ] \
  || am_fail "The manifests in Git were changed (replicas=$git_replicas, max-discount-percent=$git_discount): Git is the intended state here, the live objects must follow it"
am_ok "Git still asks for 2 replicas and max-discount-percent=5"

[ "$(am_app_json "$APP" | jq -r '.spec.syncPolicy.automated.selfHeal // false')" = true ] \
  || am_fail "Application '$APP' does not undo manual changes to live objects by itself"
am_ok "Application '$APP' heals drift by itself"

am_wait 90 bash -c "[ \"\$(kubectl -n pricing get deploy pricing-api -o jsonpath='{.spec.replicas}')\" = 2 ]" \
  || am_fail "Deployment pricing-api runs with $(am_jsonpath deploy/pricing-api '{.spec.replicas}' pricing) replicas, Git says 2"
[ "$(am_jsonpath configmap/pricing-rules '{.data.max-discount-percent}' pricing)" = 5 ] \
  || am_fail "ConfigMap pricing-rules still carries max-discount-percent=$(am_jsonpath configmap/pricing-rules '{.data.max-discount-percent}' pricing)"
am_ok "live Deployment and ConfigMap equal Git"

am_require_app_at_head "$APP" pricing-api
am_wait_rollout deploy/pricing-api pricing 60s
body="$(am_http http://pricing-api.pricing pricing)" || am_fail "Service pricing-api in namespace pricing does not answer"
[ "$body" = "pricing-api v2.0" ] || am_fail "Service pricing-api answers '$body'"
am_pass "pricing-api follows Git again, and will keep doing so"

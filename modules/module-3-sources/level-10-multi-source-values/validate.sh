#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=pricing
am_app_exists "$APP" || am_fail "Application '$APP' does not exist in namespace argocd"
json="$(am_app_json "$APP")"

n="$(echo "$json" | jq '.spec.sources // [] | length')"
[ "$n" = 2 ] || am_fail "Application '$APP' has $n source(s); the chart and the values come from two different repos"
charts="$(am_repo_url pricing-charts | sed 's/\.git$//')"
envrepo="$(am_repo_url pricing-env | sed 's/\.git$//')"
ci="$(echo "$json" | jq --arg r "$charts" '[.spec.sources | to_entries[] | select((.value.repoURL|sub("\\.git$";"")) == $r and (.value.path // "") != "")] | .[0].key // -1')"
vi="$(echo "$json" | jq --arg r "$envrepo" '[.spec.sources | to_entries[] | select((.value.repoURL|sub("\\.git$";"")) == $r)] | .[0].key // -1')"
[ "$ci" != -1 ] || am_fail "no source of '$APP' deploys the chart from pricing-charts"
[ "$vi" != -1 ] || am_fail "no source of '$APP' reads the pricing-env repo"
ref="$(echo "$json" | jq -r ".spec.sources[$vi].ref // \"\"")"
[ -n "$ref" ] || am_fail "the pricing-env source of '$APP' is not exposed with a ref"
echo "$json" | jq -e --arg p "\$$ref/prod/values.yaml" '.spec.sources['"$ci"'].helm.valueFiles // [] | index($p)' >/dev/null \
  || am_fail "the chart source of '$APP' does not read prod/values.yaml from the pricing-env source (ref '$ref')"
echo "$json" | jq -e '.spec.sources['"$ci"'].helm | (.parameters // []) == [] and (.values // "") == "" and (.valuesObject // {}) == {}' >/dev/null \
  || am_fail "the chart source of '$APP' carries inline value overrides; the values belong in the pricing-env repo"
am_ok "chart from pricing-charts, values from pricing-env/prod/values.yaml via ref '$ref'"

[ "$(am_app_sync "$APP")" = Synced ] || am_fail "Application '$APP' is $(am_app_sync "$APP") (expected Synced)"
revs="$(echo "$json" | jq -c '.status.sync.revisions // []')"
[ "$(echo "$revs" | jq -r ".[$ci] // \"\"")" = "$(am_repo_head pricing-charts)" ] \
  && [ "$(echo "$revs" | jq -r ".[$vi] // \"\"")" = "$(am_repo_head pricing-env)" ] \
  || am_fail "Application '$APP' is not synced to the current heads of both repos"
[ "$(am_app_health "$APP")" = Healthy ] || am_fail "Application '$APP' health is $(am_app_health "$APP") (expected Healthy)"
am_ok "Application '$APP' is Synced and Healthy at the current heads of both repos"

[ -n "$(am_jsonpath deploy/pricing-quote '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' pricing)" ] \
  || am_fail "Deployment pricing-quote is missing or not managed by Argo CD"
[ "$(am_ready_replicas pricing-quote pricing)" -ge 2 ] || am_fail "Deployment pricing-quote has fewer than 2 ready pods"
body="$(am_http http://pricing-quote.pricing pricing)" || am_fail "Service pricing-quote does not answer"
[ "$body" = "pricing v2.4 prod" ] || am_fail "Service pricing-quote answers '$body'"
am_pass "pricing runs with the production values from pricing-env"

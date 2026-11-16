#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=media-gateway
am_app_exists "$APP" || am_fail "Application '$APP' does not exist (it must stay, not be deleted)"

am_require_app_at_head "$APP" media-gateway

json="$(am_app_json "$APP")"
left="$(echo "$json" | jq -r '[(.spec.source.helm.parameters // [])[] | select(.name|startswith("release"))] | length')"
[ "$left" = 0 ] || am_fail "The Application still carries Helm parameters for the release version"
vo="$(echo "$json" | jq -r '.spec.source.helm.valuesObject.release.version // empty')"
[ -z "$vo" ] || am_fail "The Application still overrides the release version inline"
vs="$(echo "$json" | jq -r '.spec.source.helm.values // empty' | grep -c 'version' || true)"
[ "$vs" = 0 ] || am_fail "The Application still overrides the release version inline"
am_ok "The Application carries no override for the release version"

am_repo_checkout media-gateway "$AM_TMP/co" || am_fail "cannot clone media-gateway"
want="$(am_yaml_get "$AM_TMP/co/chart/values.yaml" release.version | jq -r .)"
[ "$want" != "1.9.1-hotfix" ] || am_fail "Git was changed to carry the hotfix version - the hotfix should be gone, not copied"

body="$(am_http http://media-gateway.media media)" || am_fail "Service media-gateway in namespace media does not answer"
[ "$body" = "media-gateway $want" ] || am_fail "Service media-gateway answers '$body', but the chart in Git says '$want'"
am_pass "media-gateway serves the version that Git declares ($want)"

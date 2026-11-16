#!/bin/bash
set -uo pipefail
source "$AM_LIB"

for a in cart-service promo-banner; do
  am_app_exists "$a" || am_fail "Application '$a' does not exist in namespace argocd"
done

# Git: exactly one of the two folders owns ConfigMap feature-flags
am_repo_checkout storefront-apps "$AM_TMP/git" || am_fail "cannot clone repo storefront-apps"
owners=()
for pair in cart-service:cart promo-banner:promo; do
  app="${pair%%:*}"; dir="${pair##*:}"
  c="$(am_yaml_docs_json "$AM_TMP/git/$dir" | jq '[.[] | select(.kind=="ConfigMap" and .metadata.name=="feature-flags")] | length')"
  [ "$c" -ge 1 ] && owners+=("$app:$dir")
done
[ "${#owners[@]}" -ge 2 ] && am_fail "ConfigMap feature-flags is still defined in the folders of both Applications"
[ "${#owners[@]}" -eq 1 ] || am_fail "ConfigMap feature-flags is defined in neither folder of the repo"
owner="${owners[0]%%:*}"; odir="${owners[0]##*:}"
am_ok "Only $owner defines feature-flags in Git ($odir/)"

for a in cart-service promo-banner; do
  am_require_app_at_head "$a" storefront-apps
  am_app_conditions "$a" | grep -q '^SharedResourceWarning' && am_fail "Application '$a' still reports SharedResourceWarning"
done
am_ok "Neither Application reports a shared resource"

tid="$(am_jsonpath cm/feature-flags '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' storefront)"
case "$tid" in "$owner":*) ;; *) am_fail "ConfigMap feature-flags is tracked as '${tid:-<none>}'";; esac
am_ok "ConfigMap feature-flags is tracked by $owner"

flags="$(kubectl -n storefront get cm feature-flags -o json 2>/dev/null | jq -c '.data // {}')"
[ "$(echo "$flags" | jq -r '.checkout_v2')" = true ] && [ "$(echo "$flags" | jq -r '.promo_banner')" = on ] \
  || am_fail "ConfigMap feature-flags holds $flags; both services need their flag (checkout_v2=true, promo_banner=on)"
am_ok "feature-flags holds both flags: $flags"

[ "$(am_http http://cart-service.storefront storefront)" = "cart-service v4.1" ] || am_fail "Service cart-service does not answer 'cart-service v4.1'"
[ "$(am_http http://promo-banner.storefront storefront)" = "promo-banner v2.3" ] || am_fail "Service promo-banner does not answer 'promo-banner v2.3'"
am_pass "feature-flags has one owner and both services are in sync"

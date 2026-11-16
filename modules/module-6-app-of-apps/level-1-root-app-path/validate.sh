#!/bin/bash
set -uo pipefail
source "$AM_LIB"

ROOT=shopfront-root
am_require_app_at_head "$ROOT" shopfront-fleet

for pair in cart-svc:shop-cart:"cart-svc v1.0" catalog-svc:shop-catalog:"catalog-svc v2.3"; do
  IFS=: read -r child ns want <<<"$pair"
  am_app_exists "$child" || am_fail "Application '$child' does not exist in namespace argocd: the shop service is not deployed"
  tracking="$(am_app "$child" '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}')"
  case "$tracking" in
    "$ROOT":*) ;;
    *) am_fail "Application '$child' exists but '$ROOT' does not manage it (it was created by hand)" ;;
  esac
  am_require_app_at_head "$child" shopfront-fleet
  body="$(am_http "http://$child.$ns" "$ns")" || am_fail "Service $child in namespace $ns does not answer"
  [ "$body" = "$want" ] || am_fail "Service $child answers '$body'"
done
am_pass "shopfront-root generates cart-svc and catalog-svc, both live"

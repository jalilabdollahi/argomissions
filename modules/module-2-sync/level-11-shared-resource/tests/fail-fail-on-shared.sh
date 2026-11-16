#!/bin/bash
# Wrong: FailOnSharedResource on both Applications. Git still declares the ConfigMap twice.
set -euo pipefail
source "$AM_LIB"

for a in cart-service promo-banner; do
  kubectl -n argocd patch application "$a" --type merge -p '{"spec":{"syncPolicy":{"syncOptions":["FailOnSharedResource=true"]}}}'
  am_app_refresh "$a"
done
sleep 15

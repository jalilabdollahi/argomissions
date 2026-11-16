#!/bin/bash
# Correct too: promo-banner becomes the owner, cart-service lets go of the ConfigMap.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/storefront-apps"
git rm -q cart/feature-flags.yaml
echo '  checkout_v2: "true"' >> promo/feature-flags.yaml
am_player_push . "feature-flags: single owner (promo-banner)"
am_app_refresh cart-service
am_app_refresh promo-banner
# Both apps auto-sync; an explicit sync may collide with the automated one ("another operation is already in progress").
am_argocd app sync promo-banner --timeout 120 || true
am_wait_app promo-banner sync=Synced health=Healthy --timeout 120
am_wait_app cart-service sync=Synced health=Healthy --timeout 120

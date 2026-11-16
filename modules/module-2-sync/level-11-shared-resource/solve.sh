#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# one owner: cart-service keeps feature-flags with both flags, promo-banner stops declaring it
cd "$SANDBOX/storefront-apps"
git rm -q promo/feature-flags.yaml
cat >> cart/feature-flags.yaml <<'YAML'
  promo_banner: "on"
YAML
am_player_push . "feature-flags: single owner (cart-service), merge both flags"
am_app_refresh cart-service
am_app_refresh promo-banner
am_wait_app cart-service sync=Synced health=Healthy --timeout 120
am_wait_app promo-banner sync=Synced health=Healthy --timeout 120

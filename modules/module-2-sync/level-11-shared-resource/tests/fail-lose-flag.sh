#!/bin/bash
# Wrong: promo-banner's copy is deleted without merging its key into cart-service's.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/storefront-apps"
git rm -q promo/feature-flags.yaml
am_player_push . "promo-banner: drop duplicate feature-flags"
am_app_refresh cart-service
am_app_refresh promo-banner
am_wait_app promo-banner sync=Synced health=Healthy --timeout 120
am_wait_app cart-service sync=Synced health=Healthy --timeout 120

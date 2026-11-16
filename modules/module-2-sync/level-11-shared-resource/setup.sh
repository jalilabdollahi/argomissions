#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed storefront-apps "$LEVEL_DIR/repo" "cart-service and promo-banner"
kubectl create namespace storefront >/dev/null

# cart-service is deployed first and owns feature-flags ...
am_app_apply "$LEVEL_DIR/assets/app-cart-service.yaml"
am_app_refresh cart-service
am_wait_app cart-service sync=Synced health=Healthy --timeout 120 || { echo "setup: cart-service did not deploy"; exit 1; }

# ... then promo-banner is added with its own copy of the same ConfigMap
am_app_apply "$LEVEL_DIR/assets/app-promo-banner.yaml"
am_app_refresh promo-banner
am_wait_app promo-banner cond="SharedResourceWarning" --timeout 20 2>/dev/null || true
warned() { { am_app_conditions cart-service; am_app_conditions promo-banner; } | grep -q '^SharedResourceWarning'; }
am_wait 120 warned || { echo "setup: no SharedResourceWarning appeared"; exit 1; }
sleep 10

am_workspace_clone storefront-apps

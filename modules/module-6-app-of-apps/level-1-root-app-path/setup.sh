#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed shopfront-fleet "$LEVEL_DIR/repo" "shopfront-fleet: root layout, cart and catalog"
am_app_apply "$LEVEL_DIR/assets/root.yaml"
am_app_refresh shopfront-root
am_wait_app shopfront-root sync=Synced --timeout 120 || { echo "setup: shopfront-root never became Synced"; exit 1; }
am_setup_assert "root deploys nothing" bash -c '[ "$(kubectl -n argocd get application shopfront-root -o json | jq ".status.resources // [] | length")" = 0 ]'
am_setup_assert "no child Application exists" bash -c '! kubectl -n argocd get application cart-svc'
am_workspace_clone shopfront-fleet

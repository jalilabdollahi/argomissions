#!/bin/bash
# Correct too: leave the root alone and move the child Application manifests to where it looks.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/shopfront-fleet"
git mv argocd/apps/cart.yaml apps/cart.yaml
git mv argocd/apps/catalog.yaml apps/catalog.yaml
am_player_push . "move Application manifests into apps/"
head="$(am_repo_head shopfront-fleet)"
am_app_refresh shopfront-root
am_wait_app shopfront-root rev="$head" sync=Synced --timeout 120
am_wait_app cart-svc rev="$head" sync=Synced health=Healthy --timeout 150 || { am_app_refresh cart-svc; am_wait_app cart-svc rev="$head" sync=Synced health=Healthy --timeout 120; }
am_app_refresh catalog-svc
am_wait_app catalog-svc rev="$head" sync=Synced health=Healthy --timeout 150

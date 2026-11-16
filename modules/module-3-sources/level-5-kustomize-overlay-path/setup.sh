#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed inventory-sync "$LEVEL_DIR/repo" "inventory-sync: base and overlays"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh inventory-sync
am_wait_app inventory-sync sync=OutOfSync --timeout 90 || { echo "setup: app not detected"; exit 1; }
am_app_sync_now inventory-sync
am_wait_app inventory-sync sync=Synced health=Healthy --timeout 150 || { echo "setup: first sync did not finish"; exit 1; }
am_workspace_clone inventory-sync

body="$(am_http http://inventory-sync.inventory inventory 8)" || { echo "setup: service does not answer"; exit 1; }
[ "$body" = "inventory-sync base" ] || { echo "setup: expected the base text, got '$body'"; exit 1; }

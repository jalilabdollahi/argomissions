#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed search-suggest "$LEVEL_DIR/repo" "search-suggest chart"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh search-suggest
am_wait_app search-suggest sync=OutOfSync --timeout 90 || { echo "setup: app not detected"; exit 1; }
am_app_sync_now search-suggest
am_wait_app search-suggest sync=Synced health=Healthy --timeout 150 || { echo "setup: first sync did not finish"; exit 1; }
am_workspace_clone search-suggest

body="$(am_http http://search-suggest.search search 8)" || { echo "setup: service does not answer"; exit 1; }
[ "$body" = "search-suggest dev defaults" ] || { echo "setup: expected the chart defaults, got '$body'"; exit 1; }

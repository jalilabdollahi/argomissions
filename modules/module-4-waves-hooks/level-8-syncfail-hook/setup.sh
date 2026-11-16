#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed booking-portal "$LEVEL_DIR/repo" "booking-portal v5.1"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh booking-portal
am_wait_app booking-portal sync=OutOfSync --timeout 120 || { echo "setup: booking-portal never became OutOfSync"; exit 1; }
am_app_sync_now booking-portal
am_wait_app booking-portal op=Succeeded sync=Synced health=Healthy --timeout 150 || { echo "setup: v5.1 did not sync"; exit 1; }
am_setup_assert "the banner was lowered after v5.1" bash -c '! kubectl -n bookings get configmap maintenance-flag'

# Release v5.2 adds a schema gate that fails: the sync fails after the banner went up.
am_repo_commit booking-portal "$LEVEL_DIR/assets/release" "release v5.2: schema-gate pre-sync check"
head="$(am_repo_head booking-portal)"
am_app_refresh booking-portal
am_wait_app booking-portal sync=OutOfSync rev="$head" --timeout 120 || { echo "setup: Application did not see v5.2"; exit 1; }
am_app_sync_now booking-portal "$head"
am_wait_app booking-portal op=Failed --timeout 120 || { echo "setup: the v5.2 sync did not fail"; exit 1; }
am_setup_assert "the banner is still up" kubectl -n bookings get configmap maintenance-flag
am_workspace_clone booking-portal

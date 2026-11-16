#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed booking-web "$LEVEL_DIR/repo" "booking-web v1.4 with PostSync smoke test"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh booking-web
am_wait_app booking-web sync=OutOfSync --timeout 120 || { echo "setup: booking-web never became OutOfSync"; exit 1; }
am_app_sync_now booking-web
am_wait_app booking-web op=Failed --timeout 150 || { echo "setup: the sync did not fail on the smoke test"; exit 1; }
am_setup_assert "the app itself is up" bash -c "[ \"\$(source '$AM_LIB'; am_http http://booking-web.booking booking)\" = 'booking-web v1.4' ]"
am_workspace_clone booking-web

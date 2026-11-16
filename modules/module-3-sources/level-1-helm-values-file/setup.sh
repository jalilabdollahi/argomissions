#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed weather-api "$LEVEL_DIR/repo" "weather-api chart with production values"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh weather-api
am_workspace_clone weather-api

am_wait_app weather-api cond=ComparisonError --timeout 120 \
  || { echo "setup: the Application never reported a manifest generation error"; exit 1; }
am_setup_assert "nothing runs in namespace weather" bash -c '! kubectl -n weather get deploy weather-api'

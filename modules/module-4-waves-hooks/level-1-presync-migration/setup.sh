#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed payroll-api "$LEVEL_DIR/repo" "payroll-api v1 manifests"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh payroll-api
am_wait_app payroll-api sync=OutOfSync --timeout 120 || { echo "setup: payroll-api never became OutOfSync"; exit 1; }
am_app_sync_now payroll-api
am_wait_app payroll-api op=Succeeded sync=Synced health=Healthy --timeout 150 || { echo "setup: v1 did not sync"; exit 1; }
am_setup_assert "v1 is live" bash -c "[ \"\$(source '$AM_LIB'; am_http http://payroll-api.payroll payroll)\" = 'payroll-api v1' ]"

# Release v2: new image + a migration Job that is a plain resource (no hook, no wave).
am_repo_commit payroll-api "$LEVEL_DIR/assets/release" "release v2: add overtime rate, schema migration 0042"
head="$(am_repo_head payroll-api)"
am_app_refresh payroll-api
am_wait_app payroll-api sync=OutOfSync rev="$head" --timeout 120 || { echo "setup: Application did not see release v2"; exit 1; }
am_workspace_clone payroll-api

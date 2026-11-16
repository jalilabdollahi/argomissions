#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed helpdesk-api "$LEVEL_DIR/repo" "helpdesk-api v1 manifests"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh helpdesk-api
am_wait_app helpdesk-api sync=OutOfSync --timeout 120 || { echo "setup: helpdesk-api never became OutOfSync"; exit 1; }
am_app_sync_now helpdesk-api
am_wait_app helpdesk-api op=Succeeded sync=Synced health=Healthy --timeout 150 || { echo "setup: v1 did not sync"; exit 1; }
am_setup_assert "v1 is live" bash -c "[ \"\$(source '$AM_LIB'; am_http http://helpdesk-api.helpdesk helpdesk)\" = 'helpdesk-api v1' ]"

# Release v2 changes the migration: the first sync of it fails on the Job left behind by release v1.
am_repo_commit helpdesk-api "$LEVEL_DIR/assets/release" "release v2: ticket SLA field (migration 0018)"
head="$(am_repo_head helpdesk-api)"
am_app_refresh helpdesk-api
am_wait_app helpdesk-api sync=OutOfSync rev="$head" --timeout 120 || { echo "setup: Application did not see release v2"; exit 1; }
am_app_sync_now helpdesk-api
am_wait_app helpdesk-api op=Failed opmsg="field is immutable" --timeout 120 || { echo "setup: the v2 sync did not fail on the Job"; exit 1; }
am_workspace_clone helpdesk-api

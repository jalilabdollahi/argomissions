#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed ticket-desk "$LEVEL_DIR/repo" "ticket-desk v3.0"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh ticket-desk
am_wait_app ticket-desk sync=OutOfSync --timeout 120 || { echo "setup: ticket-desk never became OutOfSync"; exit 1; }
am_app_sync_now ticket-desk
am_wait_app ticket-desk op=Succeeded sync=Synced health=Healthy --timeout 150 || { echo "setup: v3.0 did not sync"; exit 1; }

# The v3.1 release: new Deployment version plus the reindex Job (annotated with a typo'd hook phase).
am_repo_commit ticket-desk "$LEVEL_DIR/assets/release" "release v3.1: add reindex-tickets pre-sync hook"
head="$(am_repo_head ticket-desk)"
am_app_refresh ticket-desk
am_wait_app ticket-desk sync=OutOfSync rev="$head" --timeout 120 || { echo "setup: Application did not see v3.1"; exit 1; }
am_app_sync_now ticket-desk "$head"
am_wait_app ticket-desk op=Succeeded sync=Synced health=Healthy rev="$head" --timeout 150 || { echo "setup: v3.1 did not sync"; exit 1; }

am_setup_assert "v3.1 is live" bash -c "[ \"\$(source '$AM_LIB'; am_http http://ticket-desk.helpdesk helpdesk)\" = 'ticket-desk v3.1' ]"
am_setup_assert "the reindex Job never ran" bash -c '[ -z "$(kubectl -n helpdesk get jobs -o name)" ]'
am_workspace_clone ticket-desk

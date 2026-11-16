#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed search-api "$LEVEL_DIR/repo" "search-api v2.2 manifests"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh search-api
am_wait_app search-api sync=OutOfSync --timeout 120 || { echo "setup: search-api never became OutOfSync"; exit 1; }
am_app_sync_now search-api
am_wait_app search-api op=Succeeded sync=Synced health=Healthy --timeout 150 || { echo "setup: v2.2 did not sync"; exit 1; }
am_setup_assert "v2.2 is live" bash -c "[ \"\$(source '$AM_LIB'; am_http http://search-api.search search)\" = 'search-api v2.2' ]"

# The release manager's commit: merged to main, but nobody pressed Sync (manual sync policy).
am_repo_commit search-api "$LEVEL_DIR/assets/release" "release v2.3"
head="$(am_repo_head search-api)"
am_app_refresh search-api
am_wait_app search-api sync=OutOfSync rev="$head" --timeout 120 || { echo "setup: Application did not see the new commit"; exit 1; }
am_workspace_clone search-api

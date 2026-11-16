#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed fleet-tracker "$LEVEL_DIR/repo" "fleet-tracker v1.3"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh fleet-tracker
am_wait_app fleet-tracker sync=OutOfSync --timeout 120 || { echo "setup: fleet-tracker never became OutOfSync"; exit 1; }
am_app_sync_now fleet-tracker
am_wait_app fleet-tracker op=Succeeded sync=Synced health=Healthy --timeout 150 || { echo "setup: v1.3 did not sync"; exit 1; }
am_setup_assert "v1.3 is live" bash -c "[ \"\$(source '$AM_LIB'; am_http http://tracker-web.fleet fleet)\" = 'fleet-tracker v1.3' ]"

# Release v1.4 changes the API's readiness probe; the sync started for it never gets past wave 0.
am_repo_commit fleet-tracker "$LEVEL_DIR/assets/release" "release v1.4: tracker-api readiness probe on /healthz"
head="$(am_repo_head fleet-tracker)"
am_app_refresh fleet-tracker
am_wait_app fleet-tracker sync=OutOfSync rev="$head" --timeout 120 || { echo "setup: Application did not see v1.4"; exit 1; }
am_app_sync_now fleet-tracker "$head"
am_wait_app fleet-tracker op=Running --timeout 60 || { echo "setup: sync did not start"; exit 1; }
am_wait 90 bash -c "kubectl -n fleet get pods -l app=tracker-api -o json | jq -e '[.items[]|select(.status.containerStatuses[0].ready==false and .status.containerStatuses[0].state.running)]|length>=1'" \
  || { echo "setup: the new tracker-api pod never started"; exit 1; }
sleep 15
am_setup_assert "the sync is stuck in wave 0" bash -c '[ "$(source "$AM_LIB"; am_app_op fleet-tracker)" = Running ]'
am_setup_assert "tracker-web is still v1.3" bash -c "[ \"\$(source '$AM_LIB'; am_http http://tracker-web.fleet fleet)\" = 'fleet-tracker v1.3' ]"
am_workspace_clone fleet-tracker

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed beacon-fleet "$LEVEL_DIR/repo" "beacon-fleet: root layout, db (wave 1) and api (wave 2)"
am_app_apply "$LEVEL_DIR/assets/root.yaml"
am_app_refresh beacon-root
am_wait_app beacon-root sync=OutOfSync --timeout 120 || { echo "setup: beacon-root never saw the repo"; exit 1; }
am_app_sync_now beacon-root
am_wait_app beacon-root op=Succeeded --timeout 120 || { echo "setup: root sync did not finish"; exit 1; }
am_wait_app beacon-db sync=Synced health=Healthy --timeout 180 || { echo "setup: beacon-db is not healthy"; exit 1; }
am_wait_app beacon-api sync=Synced health=Healthy --timeout 180 || { echo "setup: beacon-api is not healthy"; exit 1; }

# The broken state: beacon-api was created before beacon-db's workload became available.
db_ready="$(kubectl -n beacon-data get deploy beacon-db -o jsonpath='{.status.conditions[?(@.type=="Available")].lastTransitionTime}')"
api_created="$(am_app beacon-api '{.metadata.creationTimestamp}')"
[ -n "$db_ready" ] && [[ "$api_created" < "$db_ready" ]] || { echo "setup: waves unexpectedly held (api $api_created, db $db_ready)"; exit 1; }
am_workspace_clone beacon-fleet

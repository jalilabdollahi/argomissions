#!/bin/bash
# Wrong: the wave numbers are spread out in Git (db -5, api 10). Waves only gate on health, and Application
# resources have none, so nothing changes.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/beacon-fleet"
sed -i.bak 's/sync-wave: "1"/sync-wave: "-5"/' apps/db.yaml
sed -i.bak 's/sync-wave: "2"/sync-wave: "10"/' apps/api.yaml
rm -f apps/*.bak
am_player_push . "spread the sync waves"
head="$(am_repo_head beacon-fleet)"
am_app_refresh beacon-root
am_wait_app beacon-root rev="$head" --timeout 120
am_argocd app sync beacon-root --timeout 180
am_wait_app beacon-root sync=Synced --timeout 120

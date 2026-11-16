#!/bin/bash
# Correct too: fix the annotation with a hook value list (PreSync only) and start the sync like the UI button.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/ticket-desk"
sed -i.bak 's/hook: PreSynk/hook: PreSync/' deploy/reindex-job.yaml && rm -f deploy/reindex-job.yaml.bak
am_player_push . "reindex-tickets: PreSync hook"
head="$(am_repo_head ticket-desk)"
am_app_refresh ticket-desk
am_wait_app ticket-desk rev="$head" --timeout 120
am_app_sync_now ticket-desk "$head"
am_wait_app ticket-desk op=Succeeded sync=Synced health=Healthy rev="$head" --timeout 120

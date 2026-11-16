#!/bin/bash
# Wrong: the annotation is fixed in Git, but nobody syncs, so the hook has never run.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/ticket-desk"
sed -i.bak 's/hook: PreSynk/hook: PreSync/' deploy/reindex-job.yaml && rm -f deploy/reindex-job.yaml.bak
am_player_push . "reindex-tickets: fix hook annotation"
am_app_refresh ticket-desk
sleep 5

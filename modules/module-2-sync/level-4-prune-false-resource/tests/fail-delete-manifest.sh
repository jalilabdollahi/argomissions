#!/bin/bash
# Wrong: just delete the manifest. Auto-prune deletes the claim (it lingers Terminating while the pod uses it).
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/media-store"
git rm -q deploy/pvc.yaml
am_player_push . "uploads: moves to the storage app"
am_app_refresh media-store
am_wait_app media-store op=Succeeded rev="$(am_repo_head media-store)" --timeout 120
sleep 5

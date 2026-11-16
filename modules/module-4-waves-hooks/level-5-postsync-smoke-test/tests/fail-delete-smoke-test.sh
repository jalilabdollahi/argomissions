#!/bin/bash
# Wrong: delete the smoke test so the sync turns green.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/booking-web"
git rm -q deploy/smoke-test.yaml
am_player_push . "remove the smoke test"
am_app_refresh booking-web
am_wait_app booking-web rev="$(am_repo_head booking-web)" --timeout 90
am_argocd app sync booking-web --timeout 150
am_wait_app booking-web sync=Synced health=Healthy op=Succeeded --timeout 120

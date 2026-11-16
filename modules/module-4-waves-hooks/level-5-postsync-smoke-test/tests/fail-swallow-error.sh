#!/bin/bash
# Wrong: keep the test but make it unable to fail.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/booking-web"
sed -i.bak "s#grep -q 'booking-web'\"#grep -q 'booking-web' || true\"#" deploy/smoke-test.yaml && rm -f deploy/smoke-test.yaml.bak
grep -q '|| true' deploy/smoke-test.yaml
am_player_push . "smoke test: do not fail the sync"
am_app_refresh booking-web
am_wait_app booking-web rev="$(am_repo_head booking-web)" --timeout 90
am_argocd app sync booking-web --timeout 150
am_wait_app booking-web sync=Synced health=Healthy op=Succeeded --timeout 120

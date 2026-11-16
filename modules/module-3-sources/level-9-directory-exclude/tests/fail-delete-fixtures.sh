#!/bin/bash
# Wrong: remove the fixtures from Git. Production is clean, but CI loses its test data.
set -euo pipefail
source "$AM_LIB"

git -C "$SANDBOX/telemetry-agents" rm -q -r deploy/tests
am_player_push "$SANDBOX/telemetry-agents" "drop CI fixtures"
am_wait_app collector sync=Synced health=Healthy --timeout 150

#!/bin/bash
# Wrong: the flag is committed to Git (and synced) instead of being operational state behind an action.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/ferry-booking"
python3 - <<'PY'
p = "deploy/deployment.yaml"
s = open(p).read().replace("  labels: {app: ferry-booking}\nspec:", "  labels: {app: ferry-booking}\n  annotations:\n    ferry.argomissions.io/maintenance: \"on\"\nspec:", 1)
open(p, "w").write(s)
PY
am_player_push "$SANDBOX/ferry-booking" "maintenance on"
am_app_refresh ferry-booking
am_wait_app ferry-booking sync=Synced health=Healthy --timeout 120

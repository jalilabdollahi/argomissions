#!/bin/bash
# Also correct: keep Chart.yaml and rename the library chart's directory to match.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/notify-platform"
git mv charts/notify-common charts/notify-commons
am_player_push "$SANDBOX/notify-platform" "rename library chart directory"
am_argocd app get notify --refresh >/dev/null
am_argocd app sync notify --timeout 120
am_wait_app notify sync=Synced health=Healthy --timeout 120

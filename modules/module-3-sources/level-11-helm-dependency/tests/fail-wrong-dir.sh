#!/bin/bash
# Wrong: a different, still non-existent path ("../common"). The error just changes its text.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/notify-platform"
sed -i.bak 's#file://../notify-commons#file://../common#' charts/notify/Chart.yaml && rm -f charts/notify/Chart.yaml.bak
am_player_push "$SANDBOX/notify-platform" "try another path"
am_argocd app get notify --refresh >/dev/null || true
sleep 5

#!/bin/bash
# Wrong: the path is fixed in Git but the Application is never synced.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/notify-platform"
sed -i.bak 's#file://../notify-commons#file://../notify-common#' charts/notify/Chart.yaml && rm -f charts/notify/Chart.yaml.bak
am_player_push "$SANDBOX/notify-platform" "fix notify-common dependency path"
am_argocd app get notify --refresh >/dev/null
am_wait_app notify sync=OutOfSync --timeout 60

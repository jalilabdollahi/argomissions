#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/notify-platform"
sed -i.bak 's#file://../notify-commons#file://../notify-common#' charts/notify/Chart.yaml && rm -f charts/notify/Chart.yaml.bak
am_player_push "$SANDBOX/notify-platform" "fix notify-common dependency path"
am_argocd app get notify --refresh >/dev/null
am_argocd app sync notify --timeout 120
am_argocd app wait notify --health --timeout 120

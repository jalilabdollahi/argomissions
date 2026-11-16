#!/bin/bash
# Wrong: copy the shared helpers into the notify chart and drop the dependency. It deploys, but the
# library chart is no longer used.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/notify-platform/charts"
cp notify-common/templates/_helpers.tpl notify/templates/_helpers.tpl
sed -i.bak '/^dependencies:/,$d' notify/Chart.yaml && rm -f notify/Chart.yaml.bak
am_player_push "$SANDBOX/notify-platform" "inline helpers"
am_argocd app get notify --refresh >/dev/null
am_argocd app sync notify --timeout 120
am_wait_app notify sync=Synced health=Healthy --timeout 120

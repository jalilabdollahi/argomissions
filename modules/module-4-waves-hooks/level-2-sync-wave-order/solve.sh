#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/shipping-ui"
sed -i.bak 's/sync-wave: "1"/sync-wave: "-1"/' deploy/configmap.yaml && rm -f deploy/configmap.yaml.bak
am_player_push . "apply the ConfigMap before the Deployment (wave -1)"
am_app_refresh shipping-ui
am_wait_app shipping-ui sync=OutOfSync rev="$(am_repo_head shipping-ui)" --timeout 90
am_argocd app terminate-op shipping-ui || true
am_wait 60 bash -c "[ \"\$(source '$AM_LIB'; am_app_op shipping-ui)\" != Running ]"
am_argocd app sync shipping-ui --timeout 150
am_argocd app wait shipping-ui --health --timeout 120

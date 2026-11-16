#!/bin/bash
# Correct too: leave the ConfigMap in wave 1 and move the Deployment to wave 2.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/shipping-ui"
sed -i.bak 's/^  name: shipping-ui$/  name: shipping-ui\n  annotations:\n    argocd.argoproj.io\/sync-wave: "2"/' deploy/deployment.yaml && rm -f deploy/deployment.yaml.bak
am_player_push . "Deployment in wave 2, after the config"
am_app_refresh shipping-ui
am_wait_app shipping-ui sync=OutOfSync rev="$(am_repo_head shipping-ui)" --timeout 90
am_argocd app terminate-op shipping-ui || true
am_wait 60 bash -c "[ \"\$(source '$AM_LIB'; am_app_op shipping-ui)\" != Running ]"
am_argocd app sync shipping-ui --timeout 150
am_wait_app shipping-ui sync=Synced health=Healthy op=Succeeded --timeout 120

#!/bin/bash
# Correct too: drop the wave annotation from the ConfigMap. In the same wave Argo CD applies ConfigMaps before
# Deployments (kind order).
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/shipping-ui"
sed -i.bak '/sync-wave/d; /annotations:/d' deploy/configmap.yaml && rm -f deploy/configmap.yaml.bak
am_player_push . "ConfigMap in the default wave"
am_app_refresh shipping-ui
am_wait_app shipping-ui sync=OutOfSync rev="$(am_repo_head shipping-ui)" --timeout 90
am_argocd app terminate-op shipping-ui || true
am_wait 60 bash -c "[ \"\$(source '$AM_LIB'; am_app_op shipping-ui)\" != Running ]"
am_argocd app sync shipping-ui --timeout 150
am_wait_app shipping-ui sync=Synced health=Healthy op=Succeeded --timeout 120

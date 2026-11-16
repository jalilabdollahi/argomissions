#!/bin/bash
set -euo pipefail
source "$AM_LIB"

sed -i.bak 's#http-echo:1\.O#http-echo:1.0#' "$SANDBOX/notifier/deploy/deployment.yaml" && rm "$SANDBOX/notifier/deploy/deployment.yaml.bak"
am_player_push "$SANDBOX/notifier" "notifier: fix image tag typo"
am_argocd app sync notifier --timeout 120
am_argocd app wait notifier --health --timeout 120

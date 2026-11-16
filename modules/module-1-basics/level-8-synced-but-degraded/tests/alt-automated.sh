#!/bin/bash
# Correct too: fix in Git, then let an automated sync policy deploy it.
set -euo pipefail
source "$AM_LIB"

sed -i.bak 's#http-echo:1\.O#http-echo:1.0#' "$SANDBOX/notifier/deploy/deployment.yaml" && rm "$SANDBOX/notifier/deploy/deployment.yaml.bak"
am_player_push "$SANDBOX/notifier" "notifier: fix image tag"
am_argocd app set notifier --sync-policy automated
am_wait_app notifier sync=Synced health=Healthy rev="$(am_repo_head notifier)" --timeout 150

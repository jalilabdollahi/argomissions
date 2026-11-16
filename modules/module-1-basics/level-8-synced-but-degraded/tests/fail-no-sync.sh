#!/bin/bash
# Wrong: the typo is fixed and pushed, but the manual Application is never synced.
set -euo pipefail
source "$AM_LIB"

sed -i.bak 's#http-echo:1\.O#http-echo:1.0#' "$SANDBOX/notifier/deploy/deployment.yaml" && rm "$SANDBOX/notifier/deploy/deployment.yaml.bak"
am_player_push "$SANDBOX/notifier" "notifier: fix image tag"
am_app_refresh notifier
am_wait_app notifier rev="$(am_repo_head notifier)" --timeout 60

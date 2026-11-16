#!/bin/bash
# Correct too: fix Git, terminate the stuck operation by clearing it through the API, then start a new sync.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/fleet-tracker"
sed -i.bak 's/port: 8080/port: 5678/' deploy/api.yaml && rm -f deploy/api.yaml.bak
am_player_push . "tracker-api: readiness probe on the container port"
head="$(am_repo_head fleet-tracker)"
am_argocd app terminate-op fleet-tracker
am_wait_app fleet-tracker op=Failed --timeout 60
am_app_refresh fleet-tracker
am_wait_app fleet-tracker rev="$head" --timeout 120
am_app_sync_now fleet-tracker "$head"
am_wait_app fleet-tracker op=Succeeded sync=Synced health=Healthy rev="$head" --timeout 150

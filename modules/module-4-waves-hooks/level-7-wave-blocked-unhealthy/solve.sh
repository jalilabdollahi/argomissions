#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app get fleet-tracker --show-operation || true
cd "$SANDBOX/fleet-tracker"
git pull -q
sed -i.bak 's/port: 8080/port: 5678/' deploy/api.yaml && rm -f deploy/api.yaml.bak
am_player_push . "tracker-api: readiness probe on the container port"
head="$(am_repo_head fleet-tracker)"
am_argocd app terminate-op fleet-tracker
am_wait_app fleet-tracker op=Failed --timeout 60 || true
am_app_refresh fleet-tracker
am_wait_app fleet-tracker rev="$head" --timeout 120
am_argocd app sync fleet-tracker --timeout 180
am_argocd app wait fleet-tracker --health --timeout 120

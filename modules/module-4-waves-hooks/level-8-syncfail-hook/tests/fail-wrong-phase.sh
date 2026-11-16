#!/bin/bash
# Wrong: move the cleanup to another success-path phase (Sync). It still never runs when the sync fails.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/booking-portal"
sed -i.bak 's/hook: PostSync/hook: Sync/' deploy/exit-maintenance.yaml && rm -f deploy/exit-maintenance.yaml.bak
am_player_push . "exit-maintenance: run as a Sync hook"
head="$(am_repo_head booking-portal)"
am_app_refresh booking-portal
am_wait_app booking-portal rev="$head" --timeout 120
am_argocd app sync booking-portal --timeout 120 || true
am_wait_app booking-portal op=Failed --timeout 60

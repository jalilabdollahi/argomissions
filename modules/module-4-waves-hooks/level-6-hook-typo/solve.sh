#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/ticket-desk"
git pull -q
sed -i.bak 's/hook: PreSynk/hook: PreSync/' deploy/reindex-job.yaml && rm -f deploy/reindex-job.yaml.bak
am_player_push . "reindex-tickets: fix hook annotation (PreSync)"
head="$(am_repo_head ticket-desk)"
am_app_refresh ticket-desk
am_wait_app ticket-desk rev="$head" --timeout 120
am_argocd app sync ticket-desk --timeout 120
am_argocd app wait ticket-desk --health --timeout 120

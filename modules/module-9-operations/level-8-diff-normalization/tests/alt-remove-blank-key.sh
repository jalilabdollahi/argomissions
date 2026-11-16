#!/bin/bash
# Correct too: drop the blank `refresh:` line and let the default stand.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/statusboard-config"
sed -i.bak '/^      refresh:$/d' deploy/statusboard.yaml && rm -f deploy/statusboard.yaml.bak
am_player_push "$SANDBOX/statusboard-config" "Drop the empty refresh"
am_argocd app get ops-statusboard --refresh >/dev/null
am_argocd app sync ops-statusboard --timeout 120
am_wait_app ops-statusboard sync=Synced health=Healthy --timeout 120

#!/bin/bash
# Correct too: Git stops pinning the replica count.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/quote-api"
sed -i.bak '/^  replicas: 2$/d' deploy/deployment.yaml && rm deploy/deployment.yaml.bak
am_player_push . "quote-api: replicas belong to the autoscaler"
am_app_refresh quote-api
am_wait_app quote-api sync=Synced health=Healthy rev="$(am_repo_head quote-api)" --timeout 150

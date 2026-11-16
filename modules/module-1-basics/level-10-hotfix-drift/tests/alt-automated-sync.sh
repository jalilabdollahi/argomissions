#!/bin/bash
# Correct too: Git first, then the Application is switched to automated sync which rolls it out.
set -euo pipefail
source "$AM_LIB"

sed -i.bak 's/^  replicas: 1$/  replicas: 3/' "$SANDBOX/checkout/deploy/deployment.yaml" && rm "$SANDBOX/checkout/deploy/deployment.yaml.bak"
am_player_push "$SANDBOX/checkout" "checkout: 3 replicas"
am_argocd app set checkout --sync-policy automated
am_wait_app checkout sync=Synced health=Healthy rev="$(am_repo_head checkout)" --timeout 150

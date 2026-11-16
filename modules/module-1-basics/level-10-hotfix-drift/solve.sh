#!/bin/bash
set -euo pipefail
source "$AM_LIB"

sed -i.bak 's/^  replicas: 1$/  replicas: 3/' "$SANDBOX/checkout/deploy/deployment.yaml" && rm "$SANDBOX/checkout/deploy/deployment.yaml.bak"
am_player_push "$SANDBOX/checkout" "checkout: 3 replicas (load spike capacity)"
am_argocd app sync checkout --timeout 120
am_argocd app wait checkout --health --timeout 120

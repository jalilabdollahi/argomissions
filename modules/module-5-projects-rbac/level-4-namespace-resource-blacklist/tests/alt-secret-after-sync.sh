#!/bin/bash
# Correct too: Git first, sync, and the Secret created afterwards (the pod recovers once it exists).
set -euo pipefail
source "$AM_LIB"

git -C "$SANDBOX/mail-relay" rm -q deploy/secret.yaml
am_player_push "$SANDBOX/mail-relay" "Remove Secret from Git (SEC-114)"
am_app_refresh mail-relay
am_wait_app mail-relay sync=OutOfSync --timeout 90 || true
am_argocd app sync mail-relay --timeout 120
kubectl -n mailroom create secret generic relay-credentials --from-literal=token=relay-token-7f3a
kubectl -n mailroom delete pod -l app=mail-relay --wait=false
am_argocd app wait mail-relay --health --timeout 120

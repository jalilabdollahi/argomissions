#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# the credential is provided out of band by the platform team ...
kubectl -n mailroom create secret generic relay-credentials --from-literal=token=relay-token-7f3a
# ... and the manifest leaves Git
git -C "$SANDBOX/mail-relay" rm -q deploy/secret.yaml
am_player_push "$SANDBOX/mail-relay" "Remove Secret from Git (SEC-114)"
am_app_refresh mail-relay
am_wait_app mail-relay sync=OutOfSync --timeout 90 || true
am_argocd app sync mail-relay --timeout 120
am_argocd app wait mail-relay --health --timeout 120

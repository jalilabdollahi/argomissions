#!/bin/bash
# Wrong (partial): the Secret manifest leaves Git, but nobody provides the Secret; the pod cannot start.
set -euo pipefail
source "$AM_LIB"

git -C "$SANDBOX/mail-relay" rm -q deploy/secret.yaml
am_player_push "$SANDBOX/mail-relay" "Remove Secret from Git"
am_app_refresh mail-relay
am_wait_app mail-relay sync=OutOfSync --timeout 90 || true
am_argocd app sync mail-relay --timeout 120
sleep 5

#!/bin/bash
# Correct too: no `git revert`, the previous flags are restored by hand in a new commit.
set -euo pipefail
source "$AM_LIB"

sed -i.bak 's#, "-workers=8", "-log-level=debug"##' "$SANDBOX/reports/deploy/deployment.yaml" && rm "$SANDBOX/reports/deploy/deployment.yaml.bak"
am_player_push "$SANDBOX/reports" "reports: restore previous worker flags"
am_argocd app sync reports --timeout 120
am_argocd app wait reports --health --timeout 120

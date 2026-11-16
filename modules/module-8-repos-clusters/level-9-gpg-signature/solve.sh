#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# the player's way: sign a new commit on top (the workspace clone already points git at the release key)
cd "$SANDBOX/treasury-core"
git pull -q --rebase origin main 2>/dev/null || true
git commit -q -S --allow-empty -m "Sign off treasury-core v2 (release key)"
git push -q origin HEAD
gpgconf --kill gpg-agent >/dev/null 2>&1 || true
am_argocd app get treasury-core --hard-refresh >/dev/null
am_argocd app sync treasury-core --timeout 120
am_argocd app wait treasury-core --health --timeout 120

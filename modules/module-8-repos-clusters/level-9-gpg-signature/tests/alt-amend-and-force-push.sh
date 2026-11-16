#!/bin/bash
# Correct too: re-sign the unsigned tip commit (nobody built on it yet) and force-push it.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/treasury-core"
git commit -q --amend -S --no-edit
git push -q --force-with-lease origin HEAD
gpgconf --kill gpg-agent >/dev/null 2>&1 || true
am_argocd app get treasury-core --hard-refresh >/dev/null
am_argocd app sync treasury-core --timeout 120
am_argocd app wait treasury-core --health --timeout 120

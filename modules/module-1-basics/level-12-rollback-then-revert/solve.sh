#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/reports"
git revert --no-edit HEAD
git push -q origin HEAD
am_argocd app sync reports --timeout 120
am_argocd app wait reports --health --timeout 120

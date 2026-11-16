#!/bin/bash
# Correct too: roll back first to stop the bleeding, then revert in Git and sync to the new head.
set -euo pipefail
source "$AM_LIB"

am_argocd app rollback reports 0 --timeout 120
am_wait_app reports health=Healthy --timeout 120
cd "$SANDBOX/reports"
git revert --no-edit HEAD
git push -q origin HEAD
am_argocd app sync reports --timeout 120
am_argocd app wait reports --health --timeout 120

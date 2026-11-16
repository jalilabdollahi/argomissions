#!/bin/bash
# Wrong: history is rewritten with a force push.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/reports"
git reset -q --hard HEAD~1
git push -q --force origin HEAD
am_app_refresh reports
am_wait_app reports rev="$(am_repo_head reports)" --timeout 60
am_argocd app sync reports --timeout 120
am_argocd app wait reports --health --timeout 120

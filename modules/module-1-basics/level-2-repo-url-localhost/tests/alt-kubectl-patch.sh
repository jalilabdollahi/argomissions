#!/bin/bash
# Correct too: patch the Application resource directly (what the UI edit does), then sync.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application orders --type merge \
  -p "{\"spec\":{\"source\":{\"repoURL\":\"$(am_repo_url orders)\"}}}"
am_app_refresh orders
am_argocd app sync orders --timeout 120
am_wait_app orders sync=Synced health=Healthy --timeout 120

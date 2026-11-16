#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app create status-page \
  --repo "$(am_repo_url status-page)" --path deploy --revision main \
  --dest-server https://kubernetes.default.svc --dest-namespace status --project default
am_argocd app sync status-page --timeout 120
am_argocd app wait status-page --health --timeout 120

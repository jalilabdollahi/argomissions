#!/bin/bash
# Wrong: the Application deploys into a new namespace named after the app instead of `status`.
set -euo pipefail
source "$AM_LIB"

am_argocd app create status-page --repo "$(am_repo_url status-page)" --path deploy \
  --dest-server https://kubernetes.default.svc --dest-namespace status-page --sync-option CreateNamespace=true
am_argocd app sync status-page --timeout 120

#!/bin/bash
# Wrong: the Application written by hand; the ApplicationSet does not own it.
set -euo pipefail
source "$AM_LIB"

am_argocd app create quota-staging --repo "$(am_repo_url quota-service)" --path deploy \
  --dest-name staging --dest-namespace quota --sync-policy automated --sync-option CreateNamespace=true
am_wait_app quota-staging sync=Synced health=Healthy --timeout 150

#!/bin/bash
# Wrong: the Application of the new tenant written by hand while the ApplicationSet stays broken.
set -euo pipefail
source "$AM_LIB"

am_argocd app create tenant-globex --repo "$(am_repo_url tenant-stack)" --path chart \
  --helm-set message="portal globex silver" \
  --dest-server https://kubernetes.default.svc --dest-namespace tenant-globex \
  --sync-policy automated --sync-option CreateNamespace=true
am_wait_app tenant-globex sync=Synced health=Healthy --timeout 150

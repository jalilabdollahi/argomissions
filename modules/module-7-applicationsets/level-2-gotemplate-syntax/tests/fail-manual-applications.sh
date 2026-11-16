#!/bin/bash
# Wrong: the three Applications written by hand; the ApplicationSet stays broken and owns nothing.
set -euo pipefail
source "$AM_LIB"

for s in dock-api dock-tracker dock-notify; do
  am_argocd app create "$s" --repo "$(am_repo_url harbor-services)" --path "services/$s" \
    --dest-server https://kubernetes.default.svc --dest-namespace harbor \
    --sync-policy automated --sync-option CreateNamespace=true
done
for s in dock-api dock-tracker dock-notify; do
  am_wait_app "$s" sync=Synced health=Healthy --timeout 150
done

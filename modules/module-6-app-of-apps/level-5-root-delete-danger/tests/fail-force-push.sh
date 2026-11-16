#!/bin/bash
# Wrong: the accident erased from history with a force push (plus the protection).
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/inventory-gitops"
git reset -q --hard HEAD~1
for f in apps/api.yaml apps/sync.yaml; do
  sed -i.bak 's#^  namespace: argocd#  namespace: argocd\n  annotations:\n    argocd.argoproj.io/sync-options: Prune=false,Delete=false#' "$f" && rm "$f.bak"
done
git add -A && git commit -q -m "protect child Applications" && git push -q --force origin HEAD
head="$(am_repo_head inventory-gitops)"
am_app_refresh inventory-root
am_wait_app inventory-root rev="$head" sync=Synced --timeout 120
am_wait_app stock-api sync=Synced health=Healthy --timeout 150
am_wait 60 bash -c 'kubectl -n argocd get application stock-sync -o jsonpath="{.metadata.annotations}" | grep -q Delete=false'
am_app_refresh stock-api; am_app_refresh stock-sync
am_wait_app stock-api rev="$head" sync=Synced health=Healthy --timeout 120

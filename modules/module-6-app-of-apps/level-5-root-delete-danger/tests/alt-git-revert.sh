#!/bin/bash
# Correct too: git revert of the accident (a new commit on top, history kept), then the protection in a second commit.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/inventory-gitops"
git revert --no-edit HEAD >/dev/null
for f in apps/api.yaml apps/sync.yaml; do
  sed -i.bak 's#^  namespace: argocd#  namespace: argocd\n  annotations:\n    argocd.argoproj.io/sync-options: Delete=false,Prune=false#' "$f" && rm "$f.bak"
done
git add -A && git commit -q -m "protect child Applications" && git push -q origin HEAD
head="$(am_repo_head inventory-gitops)"
am_app_refresh inventory-root
am_wait_app inventory-root rev="$head" sync=Synced --timeout 120
am_wait_app stock-api sync=Synced health=Healthy --timeout 150
am_wait 60 bash -c 'kubectl -n argocd get application stock-sync -o jsonpath="{.metadata.annotations}" | grep -q Delete=false'
am_app_refresh stock-api; am_app_refresh stock-sync
am_wait_app stock-api rev="$head" sync=Synced health=Healthy --timeout 120

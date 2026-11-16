#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app list
cd "$SANDBOX/inventory-gitops"
git log --stat -3
# Bring the manifest back from the commit before the accident, and protect every child.
git show HEAD~1:apps/api.yaml >apps/api.yaml
for f in apps/api.yaml apps/sync.yaml; do
  sed -i.bak 's#^  namespace: argocd#  namespace: argocd\n  annotations:\n    argocd.argoproj.io/sync-options: Prune=false,Delete=false#' "$f" && rm "$f.bak"
done
am_player_push . "restore stock-api; protect child Applications with Prune=false,Delete=false"
head="$(am_repo_head inventory-gitops)"
am_app_refresh inventory-root
am_wait_app inventory-root rev="$head" sync=Synced --timeout 120
am_wait_app stock-api sync=Synced health=Healthy --timeout 150
am_wait 60 bash -c 'kubectl -n argocd get application stock-sync -o jsonpath="{.metadata.annotations}" | grep -q Delete=false'
am_app_refresh stock-sync; am_app_refresh stock-api
am_wait_app stock-api rev="$head" sync=Synced health=Healthy --timeout 120

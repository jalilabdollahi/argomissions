#!/bin/bash
# Partial: the claim survives, but the Application stays OutOfSync because of the orphaned claim.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/media-store"
sed -i.bak 's/^  name: uploads$/  name: uploads\n  annotations:\n    argocd.argoproj.io\/sync-options: Prune=false/' deploy/pvc.yaml && rm deploy/pvc.yaml.bak
am_player_push . "uploads: Prune=false"
am_app_refresh media-store
am_wait_app media-store sync=Synced rev="$(am_repo_head media-store)" --timeout 120
am_wait 30 bash -c "kubectl -n media get pvc uploads -o jsonpath='{.metadata.annotations}' | grep -q Prune=false"
git rm -q deploy/pvc.yaml
am_player_push . "uploads: moves to the storage app"
am_app_refresh media-store
am_wait_app media-store op=Succeeded rev="$(am_repo_head media-store)" --timeout 120
sleep 5

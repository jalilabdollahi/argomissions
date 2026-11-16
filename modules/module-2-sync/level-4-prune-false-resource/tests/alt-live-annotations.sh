#!/bin/bash
# Correct too: the two annotations put on the live claim with kubectl, then the manifest leaves Git.
set -euo pipefail
source "$AM_LIB"

kubectl -n media annotate pvc uploads argocd.argoproj.io/sync-options=Prune=false argocd.argoproj.io/compare-options=IgnoreExtraneous --overwrite
cd "$SANDBOX/media-store"
git rm -q deploy/pvc.yaml
am_player_push . "uploads: moves to the storage app"
am_app_refresh media-store
am_wait_app media-store sync=Synced health=Healthy rev="$(am_repo_head media-store)" --timeout 120

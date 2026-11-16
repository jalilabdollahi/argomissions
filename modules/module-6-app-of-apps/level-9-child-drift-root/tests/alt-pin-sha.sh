#!/bin/bash
# Correct too: the child is pinned to the exact commit of the hotfix instead of the branch name.
set -euo pipefail
source "$AM_LIB"

sha="$(am_repo_head courier-services hotfix-routing)"
cd "$SANDBOX/courier-fleet"
sed -i.bak "s/targetRevision: main/targetRevision: $sha/" apps/api.yaml && rm -f apps/api.yaml.bak
am_player_push . "api: pin the hotfix commit"
head="$(am_repo_head courier-fleet)"
am_app_refresh courier-fleet
am_wait_app courier-fleet sync=Synced oprev="$head" --timeout 150
am_wait_app courier-routing sync=Synced health=Healthy --timeout 150

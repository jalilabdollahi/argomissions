#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/courier-fleet"
sed -i.bak 's/targetRevision: main/targetRevision: hotfix-routing/' apps/api.yaml && rm -f apps/api.yaml.bak
am_player_push . "api: ship hotfix-routing (v2.4.1) until it is merged"
head="$(am_repo_head courier-fleet)"
am_app_refresh courier-fleet
am_wait_app courier-fleet sync=Synced oprev="$head" --timeout 150
am_wait_app courier-routing sync=Synced health=Healthy --timeout 150

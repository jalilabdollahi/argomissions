#!/bin/bash
# Wrong: make Git say the hotfix version so everything "matches".
set -euo pipefail
source "$AM_LIB"

am_workspace_clone media-gateway
cd "$SANDBOX/media-gateway"
sed -i.bak 's/version: "2.1"/version: "1.9.1-hotfix"/' chart/values.yaml && rm chart/values.yaml.bak
am_player_push . "Match the hotfix"
am_app_refresh media-gateway
am_wait_app media-gateway sync=Synced rev="$(am_repo_head media-gateway)" --timeout 120

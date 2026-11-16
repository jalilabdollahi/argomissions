#!/bin/bash
# Wrong: change values.yaml in Git again. The Application parameter still wins.
set -euo pipefail
source "$AM_LIB"

am_workspace_clone media-gateway
cd "$SANDBOX/media-gateway"
sed -i.bak 's/version: "2.1"/version: "2.2"/' chart/values.yaml && rm chart/values.yaml.bak
am_player_push . "Release 2.2"
am_app_refresh media-gateway
am_wait_app media-gateway sync=Synced rev="$(am_repo_head media-gateway)" --timeout 120

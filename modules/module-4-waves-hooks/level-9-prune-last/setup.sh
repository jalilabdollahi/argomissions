#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed chat-relay "$LEVEL_DIR/repo" "chat-relay v1.9"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh chat-relay
am_wait_app chat-relay sync=OutOfSync --timeout 120 || { echo "setup: chat-relay never became OutOfSync"; exit 1; }
am_app_sync_now chat-relay
am_wait_app chat-relay op=Succeeded sync=Synced health=Healthy --timeout 150 || { echo "setup: v1.9 did not sync"; exit 1; }
am_setup_assert "v1.9 is live" bash -c "[ \"\$(source '$AM_LIB'; am_http http://relay.chat chat)\" = 'chat-relay v1.9' ]"

# Release v2.0, merged but not synced yet: Deployment and Service are renamed (old manifests deleted from Git).
DELETE="deploy/relay.yaml" am_repo_commit chat-relay "$LEVEL_DIR/assets/release" "release v2.0: rename relay to relay-gateway"
head="$(am_repo_head chat-relay)"
am_app_refresh chat-relay
am_wait_app chat-relay sync=OutOfSync rev="$head" --timeout 120 || { echo "setup: Application did not see v2.0"; exit 1; }
am_setup_assert "the new Service does not exist yet" bash -c '! kubectl -n chat get service relay-gateway'
am_workspace_clone chat-relay

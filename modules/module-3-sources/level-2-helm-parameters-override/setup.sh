#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed media-gateway "$LEVEL_DIR/repo" "media-gateway chart 2.0"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh media-gateway
am_wait_app media-gateway sync=Synced health=Healthy --timeout 150 \
  || { echo "setup: initial deploy did not become healthy"; exit 1; }

# The release train moves on: Git now says 2.1, but the Application still carries the incident-time override.
am_repo_commit media-gateway "$LEVEL_DIR/assets/bump" "Release 2.1"
am_app_refresh media-gateway
am_wait_app media-gateway sync=Synced health=Healthy rev="$(am_repo_head media-gateway)" --timeout 120 \
  || { echo "setup: app did not settle at the 2.1 commit"; exit 1; }
am_workspace_clone media-gateway

body="$(am_http http://media-gateway.media media 8)" || { echo "setup: gateway does not answer"; exit 1; }
[ "$body" = "media-gateway 1.9.1-hotfix" ] || { echo "setup: expected the hotfix banner, got '$body'"; exit 1; }

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed ticket-desk "$LEVEL_DIR/repo" "ticket-desk: base and overlays"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh ticket-desk
am_wait_app ticket-desk sync=OutOfSync --timeout 90 || { echo "setup: app not detected"; exit 1; }
am_app_sync_now ticket-desk
am_wait_app ticket-desk sync=Synced op=Succeeded --timeout 120 || { echo "setup: first sync did not finish"; exit 1; }
am_workspace_clone ticket-desk

img="$(am_jsonpath deploy/ticket-desk '{.spec.template.spec.containers[0].image}' desk)"
[ "$img" = "nginx:1.27-alpine" ] || { echo "setup: expected the old build, got '$img'"; exit 1; }
body="$(am_http http://ticket-desk.desk desk 8)" || { echo "setup: service does not answer"; exit 1; }
case "$body" in *"Welcome to nginx"*) ;; *) echo "setup: expected the old nginx build, got '$body'"; exit 1;; esac

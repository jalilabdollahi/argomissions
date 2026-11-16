#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# Five releases, each deployed by Argo CD, so `argocd app history` has a real trail.
am_repo_seed rates-service "$LEVEL_DIR/repo" "rates-service v1.0"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh rates-service
am_wait_app rates-service sync=Synced health=Healthy op=Succeeded --timeout 150 \
  || { echo "setup: rates-service v1.0 did not deploy"; exit 1; }

release() { # DIR MESSAGE
  am_repo_commit rates-service "$LEVEL_DIR/assets/commits/$1" "$2"
  local sha; sha="$(am_repo_head rates-service)"
  am_app_refresh rates-service
  am_wait_app rates-service sync=Synced op=Succeeded oprev="$sha" --timeout 150 \
    || { echo "setup: release '$2' was not deployed"; exit 1; }
}
release c2 "Bump rates-service to v1.1"
release c3 "Align environment values with the staging config"
release c4 "Release v1.2: run two replicas"
release c5 "Raise cache TTL to 600 seconds"

am_wait_app rates-service sync=Synced health=Healthy --timeout 150 || { echo "setup: rates-service not healthy"; exit 1; }
hist_len() { [ "$(am_app_json rates-service | jq '.status.history | length')" -ge 5 ]; }
am_setup_assert "the Application has a deployment history" hist_len
live_ok() { [ "$(source "$AM_LIB"; am_http http://rates-service.fx-rates fx-rates)" = "fx-rates v1.2 currency=USD source=ecb" ]; }
am_setup_assert "the live service shows the wrong currency" am_wait 90 live_ok
am_workspace_clone rates-service

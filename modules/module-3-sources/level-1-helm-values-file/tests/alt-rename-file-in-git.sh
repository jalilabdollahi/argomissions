#!/bin/bash
# Correct too: keep the Application as it is and give the file the name it expects, in Git.
set -euo pipefail
source "$AM_LIB"

am_workspace_clone weather-api
cd "$SANDBOX/weather-api"
git mv chart/values-production.yaml chart/values-prod.yaml
am_player_push . "Rename production values file"
am_app_refresh weather-api
am_argocd app sync weather-api --timeout 120
am_wait_app weather-api sync=Synced health=Healthy rev="$(am_repo_head weather-api)" --timeout 120

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# v0 of the repo: last quarter's rate card
mkdir -p "$AM_TMP/v0"
cp -R "$LEVEL_DIR/repo/." "$AM_TMP/v0/"
cp "$LEVEL_DIR/assets/v0-rates.yaml" "$AM_TMP/v0/deploy/rates.yaml"
am_repo_seed tollbooth "$AM_TMP/v0" "tollbooth rates 2025-Q3"
kubectl create namespace tollbooth >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh tollbooth
am_wait_app tollbooth sync=Synced health=Healthy --timeout 150 || { echo "setup: first sync did not settle"; exit 1; }

# The finance team ships the new rate card; Argo CD syncs the ConfigMap, the pods keep the old environment.
am_repo_commit tollbooth "$LEVEL_DIR/repo" "rates 2025-Q4"
head="$(am_repo_head tollbooth)"
am_app_refresh tollbooth
am_wait_app tollbooth rev="$head" sync=Synced health=Healthy --timeout 150 || { echo "setup: new rates were not synced"; exit 1; }
[ "$(am_jsonpath configmap/tollbooth-rates '{.data.RATE_CARD}' tollbooth)" = "tollbooth rates 2025-Q4" ] \
  || { echo "setup: ConfigMap not updated"; exit 1; }
sleep 3
kubectl annotate namespace tollbooth "tollbooth.argomissions.io/setup-epoch=$(date +%s)" >/dev/null
sleep 2   # anything created later is strictly newer than the marker
am_workspace_clone tollbooth

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed orders "$LEVEL_DIR/repo" "orders v1.4 manifests"
kubectl create namespace orders >/dev/null

# The developer created the Application with the URL they clone from on their laptop.
sed "s#__REPO_HOST_URL__#$(am_repo_host_url orders)#" "$LEVEL_DIR/assets/app.yaml" >"$AM_TMP/app.yaml"
am_app_apply "$AM_TMP/app.yaml"
am_app_refresh orders
am_wait_app orders cond=ComparisonError --timeout 120 || { echo "setup: no ComparisonError appeared"; exit 1; }
am_workspace_clone orders

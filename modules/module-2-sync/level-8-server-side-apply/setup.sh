#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# the repo is the static manifests plus a generated CMDB export (too big to keep in the level folder)
mkdir -p "$AM_TMP/seed"
cp -R "$LEVEL_DIR/repo/." "$AM_TMP/seed/"
"$AM_PYTHON" "$LEVEL_DIR/assets/gen_inventory.py" "$AM_TMP/seed/deploy/host-inventory.yaml"
am_repo_seed host-registry "$AM_TMP/seed" "host-registry v1.0 with full CMDB export"

kubectl create namespace netops >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh host-registry
am_wait_app host-registry sync=OutOfSync --timeout 60 || { echo "setup: app did not appear"; exit 1; }
am_argocd app sync host-registry --timeout 120 >/dev/null 2>&1 || true
am_wait_app host-registry op=Failed opmsg="Too long" --timeout 60 || { echo "setup: sync did not fail on the annotation size"; exit 1; }

am_workspace_clone host-registry

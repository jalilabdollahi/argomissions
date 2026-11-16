#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed catalog "$LEVEL_DIR/repo" "catalog v2.0 manifests"
DELETE="k8s" am_repo_commit catalog "$LEVEL_DIR/assets/restructured" "restructure: move manifests to deploy/catalog"
kubectl create namespace catalog >/dev/null

am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh catalog
am_wait_app catalog cond=ComparisonError --timeout 120 || { echo "setup: no ComparisonError appeared"; exit 1; }
am_workspace_clone catalog

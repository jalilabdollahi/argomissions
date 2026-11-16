#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed pricing-charts "$LEVEL_DIR/repos/pricing-charts" "pricing chart 0.3.0"
am_repo_seed pricing-env "$LEVEL_DIR/repos/pricing-env" "prod and staging values"
kubectl create namespace pricing >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh pricing
am_wait_app pricing cond="values" --timeout 90 || { echo "setup: no error condition"; exit 1; }
am_workspace_clone pricing-charts
am_workspace_clone pricing-env

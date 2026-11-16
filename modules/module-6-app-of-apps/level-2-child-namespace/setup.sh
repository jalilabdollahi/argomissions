#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed billing-gitops "$LEVEL_DIR/repo" "billing-gitops: root layout, invoice-api and dunning-worker"
am_app_apply "$LEVEL_DIR/assets/root.yaml"
am_app_refresh billing-root
am_wait_app billing-root op=Succeeded --timeout 120 || { echo "setup: billing-root did not sync"; exit 1; }
am_setup_assert "children landed in billing-system" bash -c '[ "$(kubectl -n billing-system get applications.argoproj.io -o name | wc -l | tr -d " ")" = 2 ]'
am_workspace_clone billing-gitops

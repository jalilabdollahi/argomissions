#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed tracing-gitops "$LEVEL_DIR/repo" "tracing-gitops: root layout, trace-collector and trace-query"
am_app_apply "$LEVEL_DIR/assets/root.yaml"
am_app_refresh tracing-root
am_wait_app tracing-root op=Succeeded --timeout 120 || { echo "setup: tracing-root did not sync"; exit 1; }
am_wait_app trace-collector cond=InvalidSpecError --timeout 120 || { echo "setup: trace-collector has no InvalidSpecError"; exit 1; }
am_wait_app trace-query cond=InvalidSpecError --timeout 120 || { echo "setup: trace-query has no InvalidSpecError"; exit 1; }
am_workspace_clone tracing-gitops

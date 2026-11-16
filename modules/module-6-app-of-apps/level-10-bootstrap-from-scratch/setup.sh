#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed lighthouse-gitops "$LEVEL_DIR/repos/lighthouse-gitops" "lighthouse-gitops: projects, apps, workloads"
am_setup_assert "no Application exists" bash -c '[ -z "$(kubectl -n argocd get applications -o name)" ]'
am_workspace_clone lighthouse-gitops

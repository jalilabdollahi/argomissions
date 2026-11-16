#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed status-page "$LEVEL_DIR/repo" "status-page v1.0 manifests"
kubectl create namespace status >/dev/null
am_workspace_clone status-page

am_setup_assert "no Application exists yet" bash -c '! kubectl -n argocd get application status-page'

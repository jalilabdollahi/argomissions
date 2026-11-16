#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# The read-only machine user Argo CD is supposed to use (the engine deletes non-player users between levels)
am_gitea DELETE /admin/users/tidewater-reader >/dev/null 2>&1 || true
am_gitea POST /admin/users '{"username":"tidewater-reader","email":"tidewater-reader@platform.local","password":"reader-pass-4Kd9","must_change_password":false}' >/dev/null

PRIVATE=1 am_repo_seed tidewater-gitops "$LEVEL_DIR/repos/tidewater-gitops" "tidewater-gitops: bootstrap, projects, apps, workloads"
am_gitea PUT /repos/platform/tidewater-gitops/collaborators/tidewater-reader '{"permission":"read"}' >/dev/null
is_private() { [ "$(am_gitea GET /repos/platform/tidewater-gitops | jq -r .private)" = true ]; }
am_setup_assert "repo is private" is_private
am_setup_assert "Argo CD is empty" bash -c '[ -z "$(kubectl -n argocd get applications,appprojects -o name | grep -v appproject.argoproj.io/default)" ]'
am_setup_assert "no repository secrets" bash -c '[ -z "$(kubectl -n argocd get secrets -l argocd.argoproj.io/secret-type -o name)" ]'
am_workspace_clone tidewater-gitops

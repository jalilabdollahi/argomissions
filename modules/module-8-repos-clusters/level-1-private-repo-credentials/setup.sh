#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# the read-only machine user Argo CD is supposed to use (the engine deletes non-player users between levels)
am_gitea DELETE /admin/users/argo-reader >/dev/null 2>&1 || true
am_gitea POST /admin/users '{"username":"argo-reader","email":"argo-reader@platform.local","password":"reader-pass-7Q2x","must_change_password":false}' >/dev/null

PRIVATE=1 am_repo_seed vault-ui "$LEVEL_DIR/repo" "vault-ui v2.4 manifests"
am_gitea PUT /repos/platform/vault-ui/collaborators/argo-reader '{"permission":"read"}' >/dev/null
kubectl create namespace vault-ui >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh vault-ui

unauth() { am_app_conditions vault-ui | grep -q 'authentication required'; }
am_wait 90 unauth || { echo "setup: Argo CD did not report 'authentication required'"; exit 1; }
is_private() { [ "$(am_gitea GET /repos/platform/vault-ui | jq -r .private)" = true ]; }
am_setup_assert "repo is private" is_private

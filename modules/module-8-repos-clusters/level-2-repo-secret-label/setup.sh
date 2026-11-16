#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_gitea DELETE /admin/users/argo-reader >/dev/null 2>&1 || true
am_gitea POST /admin/users '{"username":"argo-reader","email":"argo-reader@platform.local","password":"reader-pass-4Kd9","must_change_password":false}' >/dev/null

PRIVATE=1 am_repo_seed parcel-tracker "$LEVEL_DIR/repo" "parcel-tracker v0.9 manifests"
am_gitea PUT /repos/platform/parcel-tracker/collaborators/argo-reader '{"permission":"read"}' >/dev/null
kubectl create namespace parcels >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/repo-secret.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh parcel-tracker

unauth() { am_app_conditions parcel-tracker | grep -q 'authentication required'; }
am_wait 90 unauth || { echo "setup: Argo CD did not report 'authentication required'"; exit 1; }
no_repo() { [ -z "$(am_argocd repo list -o url 2>/dev/null | grep parcel-tracker)" ]; }
am_setup_assert "the secret is ignored (repo not listed)" no_repo

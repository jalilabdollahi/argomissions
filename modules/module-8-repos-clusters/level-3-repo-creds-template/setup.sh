#!/bin/bash
set -euo pipefail
source "$AM_LIB"

REPOS="kiosk-menu kiosk-queue kiosk-payments kiosk-signage kiosk-reports"
am_gitea DELETE /admin/users/argo-reader >/dev/null 2>&1 || true
am_gitea POST /admin/users '{"username":"argo-reader","email":"argo-reader@platform.local","password":"reader-pass-1Wm6","must_change_password":false}' >/dev/null

for r in $REPOS; do
  PRIVATE=1 am_repo_seed "$r" "$LEVEL_DIR/repos/$r" "$r manifests"
  am_gitea PUT "/repos/platform/$r/collaborators/argo-reader" '{"permission":"read"}' >/dev/null
done
kubectl create namespace kiosk >/dev/null
am_app_apply "$LEVEL_DIR/assets/apps.yaml"
for r in $REPOS; do am_app_refresh "$r"; done

all_unauth() { local r; for r in $REPOS; do am_app_conditions "$r" | grep -q 'authentication required' || return 1; done; }
am_wait 120 all_unauth || { echo "setup: not every app reports 'authentication required'"; exit 1; }

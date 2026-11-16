#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed gallery-web "$LEVEL_DIR/repo" "gallery-web v3.1 manifests"
kubectl create namespace gallery >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh gallery-web
am_wait_app gallery-web sync=Synced health=Healthy --timeout 150 || { echo "setup: first sync did not settle"; exit 1; }
am_setup_assert "legacy Service exists" kubectl -n gallery get svc gallery-classic

# The team retires the old endpoint: the manifest is deleted from Git.
DELETE="deploy/legacy-service.yaml" am_repo_commit gallery-web "" "Retire gallery-classic Service"
am_app_refresh gallery-web
am_wait_app gallery-web sync=OutOfSync --timeout 90 || { echo "setup: app did not notice the removal"; exit 1; }
sleep 10   # the automated sync must have run and left the Service alone
am_setup_assert "orphan still running" kubectl -n gallery get svc gallery-classic
am_setup_assert "still OutOfSync" bash -c '[ "$(kubectl -n argocd get application gallery-web -o jsonpath="{.status.sync.status}")" = OutOfSync ]'
am_workspace_clone gallery-web

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed media "$LEVEL_DIR/repo" "media v4.0 manifests"
kubectl create namespace media-prod >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh media
am_wait_app media sync=OutOfSync --timeout 60 || { echo "setup: app did not appear"; exit 1; }
am_app_sync_now media
am_wait_app media sync=Synced health=Healthy --timeout 120 || { echo "setup: first sync did not settle"; exit 1; }

# Remember what must not be touched: the UID of the web Deployment (validate.sh compares).
uid="$(am_jsonpath deploy/media-web '{.metadata.uid}' media-prod)"
kubectl -n argocd annotate application media "argomissions.io/baseline-web-uid=$uid" --overwrite >/dev/null

# The team retires the worker in Git; the release manager syncs without pruning.
DELETE="deploy/legacy-worker.yaml" am_repo_commit media "" "retire legacy worker"
am_app_refresh media
am_wait_app media rev="$(am_repo_head media)" --timeout 60 || { echo "setup: new commit not seen"; exit 1; }
am_app_sync_now media
am_wait_app media op=Succeeded rev="$(am_repo_head media)" --timeout 90 || { echo "setup: sync did not finish"; exit 1; }
am_app_refresh media
am_wait_app media sync=OutOfSync --timeout 60 || { echo "setup: app is not OutOfSync"; exit 1; }
am_setup_assert "worker still running" kubectl -n media-prod get deploy legacy-worker
am_workspace_clone media

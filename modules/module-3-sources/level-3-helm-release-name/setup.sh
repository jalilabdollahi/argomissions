#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed fleet-tracker "$LEVEL_DIR/repo" "fleet-tracker: plain manifests and the new chart"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh fleet-tracker
am_wait_app fleet-tracker sync=Synced health=Healthy --timeout 150 \
  || { echo "setup: plain-manifest deploy did not become healthy"; exit 1; }
am_setup_assert "tracker-api service exists before the switch" kubectl -n fleet get svc tracker-api

# The colleague's change: the Application now reads the chart instead of the plain manifests.
kubectl -n argocd patch application fleet-tracker --type merge -p '{"spec":{"source":{"path":"chart"}}}'
am_app_refresh fleet-tracker
am_wait 120 bash -c 'kubectl -n fleet get svc fleet-tracker-api >/dev/null && ! kubectl -n fleet get svc tracker-api >/dev/null 2>&1' \
  || { echo "setup: the switch to the chart did not rename the objects"; exit 1; }
am_wait_app fleet-tracker sync=Synced --timeout 120 || { echo "setup: app did not settle"; exit 1; }
am_workspace_clone fleet-tracker

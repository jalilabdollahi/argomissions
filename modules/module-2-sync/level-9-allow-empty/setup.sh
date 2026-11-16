#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed nightly-etl "$LEVEL_DIR/repo" "nightly-etl v3.2 manifests"
kubectl create namespace etl >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh nightly-etl
am_wait_app nightly-etl sync=Synced health=Healthy --timeout 120 || { echo "setup: v3.2 did not deploy"; exit 1; }

# the platform team takes the workloads over: the manifests leave this repo
DELETE="deploy/etl-worker.yaml deploy/etl-status.yaml deploy/etl-schedule.yaml" \
  am_repo_commit nightly-etl "" "move ETL workloads to the platform runtime repo"
am_app_refresh nightly-etl
am_wait_app nightly-etl sync=OutOfSync cond="auto-sync will wipe out all resources" --timeout 90 \
  || { echo "setup: auto-sync did not refuse the empty target"; exit 1; }

am_workspace_clone nightly-etl

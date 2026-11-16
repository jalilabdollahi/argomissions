#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed sensor-hub "$LEVEL_DIR/repo" "sensor-hub: Probe CRD and first instance"
am_app_apply "$LEVEL_DIR/assets/apps.yaml"
am_app_refresh sensor-hub
am_app_refresh sensor-crds
am_wait_app sensor-hub sync=OutOfSync --timeout 120 || am_wait_app sensor-hub sync=Unknown --timeout 5 || true
am_wait_app sensor-crds sync=OutOfSync --timeout 120 || { echo "setup: sensor-crds never became OutOfSync"; exit 1; }
# The team syncs the instances first: the Probe CRD does not exist yet.
am_app_sync_now sensor-hub
am_wait_app sensor-hub op=Failed --timeout 120 || { echo "setup: the sensor-hub sync did not fail"; exit 1; }
am_setup_assert "no Probe CRD on the cluster" bash -c '! kubectl get crd probes.sensors.argomissions.io'
am_workspace_clone sensor-hub

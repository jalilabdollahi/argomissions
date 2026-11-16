#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# the platform bootstrap installs the CRD ~100 s from now
kubectl apply -f "$LEVEL_DIR/assets/bootstrap.yaml" >/dev/null

am_repo_seed sensor-hub "$LEVEL_DIR/repo" "sensor-hub v2.0 with SensorProfile"
kubectl create namespace iot-edge >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh sensor-hub

# the first automated sync attempts (2 retries over ~15 s) all run before the CRD exists
am_wait_app sensor-hub op=Failed --timeout 120 || { echo "setup: automated sync did not fail"; exit 1; }
am_setup_assert "CRD is not installed yet" bash -c '! kubectl get crd sensorprofiles.runtime.argomissions.io'

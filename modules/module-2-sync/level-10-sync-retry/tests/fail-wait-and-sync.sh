#!/bin/bash
# Wrong: wait for the CRD, then sync by hand. It works today; the policy is unchanged.
set -euo pipefail
source "$AM_LIB"

am_wait 240 kubectl get crd sensorprofiles.runtime.argomissions.io
sleep 5
am_argocd app sync sensor-hub --timeout 120
am_wait_app sensor-hub sync=Synced health=Healthy op=Succeeded --timeout 120

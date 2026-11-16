#!/bin/bash
# Wrong: apply the CRD by hand to get past the error. The instance syncs, but nothing owns the CRD.
set -euo pipefail
source "$AM_LIB"

kubectl apply -f "$SANDBOX/sensor-hub/crds/probe-crd.yaml"
kubectl wait --for=condition=Established crd/probes.sensors.argomissions.io --timeout=30s
am_argocd app sync sensor-hub --timeout 120
am_argocd app wait sensor-hub --health --timeout 120

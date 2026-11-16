#!/bin/bash
# Wrong: create the ConfigMap by hand so the pod starts. The pod recovers, but Git still has the wrong order
# and the last sync never succeeded.
set -euo pipefail
source "$AM_LIB"

kubectl -n shipping apply -f "$SANDBOX/shipping-ui/deploy/configmap.yaml"
kubectl -n shipping rollout status deploy/shipping-ui --timeout=90s
am_app_refresh shipping-ui
sleep 5

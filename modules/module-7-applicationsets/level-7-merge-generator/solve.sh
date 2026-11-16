#!/bin/bash
set -euo pipefail
source "$AM_LIB"

sed -i.bak 's/^\(          - \)environment: prod/\1env: prod/' "$SANDBOX/parcel-api-appset.yaml"
rm -f "$SANDBOX/parcel-api-appset.yaml.bak"
kubectl apply -f "$SANDBOX/parcel-api-appset.yaml"
ready3() { [ "$(am_ready_replicas parcel-api parcel-prod)" = 3 ]; }
am_wait 150 ready3
am_wait_app parcel-api-prod sync=Synced health=Healthy --timeout 150

#!/bin/bash
# Wrong: the new set is applied next to the old one; the old set is never deleted and still owns the apps.
set -euo pipefail
source "$AM_LIB"

kubectl apply -f "$SANDBOX/kiosk-fleet-appset.yaml"
sleep 10

#!/bin/bash
# Wrong: the naive delete and re-apply. The apps are deleted with their finalizer and take the workloads along.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd delete applicationset kiosk-apps --wait=true
kubectl apply -f "$SANDBOX/kiosk-fleet-appset.yaml"
for r in north south east; do am_wait_app "kiosk-$r" sync=Synced health=Healthy --timeout 180; done

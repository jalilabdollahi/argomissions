#!/bin/bash
# Correct too: delete the old ApplicationSet with --cascade=orphan; the Applications stay and the new set adopts them.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd delete applicationset kiosk-apps --cascade=orphan
kubectl apply -f "$SANDBOX/kiosk-fleet-appset.yaml"
adopted() { [ "$(am_app kiosk-east '{.metadata.ownerReferences[0].name}')" = kiosk-fleet ] \
  && [ "$(am_app kiosk-north '{.metadata.ownerReferences[0].name}')" = kiosk-fleet ] \
  && [ "$(am_app kiosk-south '{.metadata.ownerReferences[0].name}')" = kiosk-fleet ]; }
am_wait 60 adopted
for r in north south east; do am_wait_app "kiosk-$r" sync=Synced health=Healthy --timeout 150; done

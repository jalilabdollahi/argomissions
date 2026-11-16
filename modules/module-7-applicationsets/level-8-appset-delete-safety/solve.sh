#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# 1. make the deletion non-cascading, 2. wait until the apps no longer carry the finalizer, 3. delete, 4. apply the new set
kubectl -n argocd patch applicationset kiosk-apps --type merge -p '{"spec":{"syncPolicy":{"preserveResourcesOnDeletion":true}}}'
no_finalizer() { [ -z "$(am_app kiosk-north '{.metadata.finalizers}')" ]; }
am_wait 60 no_finalizer
kubectl -n argocd delete applicationset kiosk-apps
gone() { ! kubectl -n argocd get applications 2>/dev/null | grep -q '^kiosk-'; }
am_wait 60 gone
kubectl apply -f "$SANDBOX/kiosk-fleet-appset.yaml"
for r in north south east; do am_wait_app "kiosk-$r" sync=Synced health=Healthy --timeout 150; done

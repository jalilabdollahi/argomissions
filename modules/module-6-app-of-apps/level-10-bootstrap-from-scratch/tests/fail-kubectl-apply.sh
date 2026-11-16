#!/bin/bash
# Wrong: the projects and the children applied by hand. Everything runs, no root owns any of it.
set -euo pipefail
source "$AM_LIB"

kubectl apply -f "$SANDBOX/lighthouse-gitops/platform/projects/"
kubectl apply -f "$SANDBOX/lighthouse-gitops/platform/apps/"
for a in lighthouse-cache lighthouse-gateway lighthouse-catalog; do
  am_wait_app "$a" sync=Synced health=Healthy --timeout 240
done

#!/bin/bash
# Wrong: the child Applications applied by hand. They run, but the root still does not own them.
set -euo pipefail
source "$AM_LIB"

kubectl apply -f "$SANDBOX/shopfront-fleet/argocd/apps/"
am_wait_app cart-svc sync=Synced health=Healthy --timeout 150
am_wait_app catalog-svc sync=Synced health=Healthy --timeout 150

#!/bin/bash
# Wrong: the child Applications applied by hand into argocd. They run, but the root does not maintain them.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd apply -f "$SANDBOX/billing-gitops/apps/"
am_wait_app invoice-api sync=Synced health=Healthy --timeout 150
am_wait_app dunning-worker sync=Synced health=Healthy --timeout 150

#!/bin/bash
# Wrong: send the US app to the EU namespace, which the cluster scope already allows.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application parcel-hub-us --type merge -p '{"spec":{"destination":{"namespace":"parcel-eu"}}}' >/dev/null
am_app_refresh parcel-hub-us normal
am_wait_app parcel-hub-us sync=Synced --timeout 120 || true

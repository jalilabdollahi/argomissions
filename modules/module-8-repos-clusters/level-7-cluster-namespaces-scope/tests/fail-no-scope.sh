#!/bin/bash
# Wrong: drop the namespace scope altogether so "everything is managed".
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch secret cluster-regional --type json -p '[{"op":"remove","path":"/data/namespaces"}]' >/dev/null
sleep 8
am_app_refresh parcel-hub-us normal
sleep 15

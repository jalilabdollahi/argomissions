#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch secret cluster-regional --type merge -p '{"stringData":{"namespaces":"parcel-eu,parcel-us"}}' >/dev/null
sleep 3
am_app_refresh parcel-hub-us normal
am_wait_app parcel-hub-us sync=Synced health=Healthy --timeout 150
am_wait_app parcel-hub-eu sync=Synced health=Healthy --timeout 60

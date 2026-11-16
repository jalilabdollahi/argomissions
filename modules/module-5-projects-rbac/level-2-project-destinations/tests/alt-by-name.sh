#!/bin/bash
# Correct too: the destination added with kubectl, by cluster name rather than server URL.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject clinic --type json \
  -p '[{"op":"add","path":"/spec/destinations/-","value":{"name":"in-cluster","namespace":"pharmacy"}}]'
am_app_refresh rx-dispatch
am_wait_app rx-dispatch sync=Synced health=Healthy --timeout 150

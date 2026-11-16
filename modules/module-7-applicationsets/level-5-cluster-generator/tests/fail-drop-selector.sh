#!/bin/bash
# Wrong: the selector is removed so that the set matches every cluster, in-cluster included.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset quota-fleet --type json \
  -p '[{"op":"remove","path":"/spec/generators/0/clusters/selector"}]'
am_wait_app quota-staging sync=Synced health=Healthy --timeout 150
am_wait 120 kubectl -n argocd get application quota-in-cluster
sleep 10

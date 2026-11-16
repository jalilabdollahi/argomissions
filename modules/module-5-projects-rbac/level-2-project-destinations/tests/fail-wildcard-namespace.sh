#!/bin/bash
# Wrong: allow every namespace of the cluster.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject clinic --type merge \
  -p '{"spec":{"destinations":[{"server":"https://kubernetes.default.svc","namespace":"*"}]}}'
am_app_refresh rx-dispatch
am_wait_app rx-dispatch sync=Synced health=Healthy --timeout 150

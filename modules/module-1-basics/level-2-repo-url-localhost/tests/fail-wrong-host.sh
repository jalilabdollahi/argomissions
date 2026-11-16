#!/bin/bash
# Wrong: another host that does not resolve from the argocd namespace (the CLI refuses it, kubectl does not).
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application orders --type merge \
  -p '{"spec":{"source":{"repoURL":"http://gitea:3000/platform/orders.git"}}}'
am_app_refresh orders
am_wait_app orders cond="no such host" --timeout 60

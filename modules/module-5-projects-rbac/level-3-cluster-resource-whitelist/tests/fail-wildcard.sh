#!/bin/bash
# Wrong: allow every cluster-scoped kind.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject radar --type merge -p '{"spec":{"clusterResourceWhitelist":[{"group":"*","kind":"*"}]}}'
am_argocd app sync radar-agent --timeout 120
am_argocd app wait radar-agent --health --timeout 120

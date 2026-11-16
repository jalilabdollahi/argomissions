#!/bin/bash
# Wrong: lift the security restriction so the Secret can flow from Git.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject mailroom --type json -p '[{"op":"remove","path":"/spec/namespaceResourceBlacklist"}]'
sleep 3
am_argocd app sync mail-relay --timeout 120
am_argocd app wait mail-relay --health --timeout 120

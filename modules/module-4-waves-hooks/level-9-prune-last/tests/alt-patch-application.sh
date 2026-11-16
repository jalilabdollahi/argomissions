#!/bin/bash
# Correct too: declare the option in the Application spec (kubectl patch), then sync with pruning like the UI button.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application chat-relay --type merge \
  -p '{"spec":{"syncPolicy":{"syncOptions":["CreateNamespace=true","PruneLast=true"]}}}'
am_argocd app sync chat-relay --prune --timeout 180
am_wait_app chat-relay op=Succeeded sync=Synced health=Healthy --timeout 120

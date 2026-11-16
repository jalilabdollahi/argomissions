#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app diff chat-relay || true
am_argocd app set chat-relay --sync-option CreateNamespace=true --sync-option PruneLast=true
am_argocd app sync chat-relay --prune --timeout 180
am_argocd app wait chat-relay --health --timeout 120

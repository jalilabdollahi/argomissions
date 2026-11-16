#!/bin/bash
# Wrong: the rename is synced with pruning as is. The old Service is deleted before the new one is ready.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync chat-relay --prune --timeout 180
am_argocd app wait chat-relay --health --timeout 120

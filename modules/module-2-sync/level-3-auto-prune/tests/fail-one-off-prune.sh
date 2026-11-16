#!/bin/bash
# Wrong: a single `sync --prune` cleans up once, the policy is unchanged.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync gallery-web --prune --timeout 120
am_wait_app gallery-web sync=Synced health=Healthy --timeout 120

#!/bin/bash
# Wrong: syncing again without prune does nothing about the orphan.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync media --timeout 120 || true

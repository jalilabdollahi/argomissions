#!/bin/bash
# Partial: the destination is fixed and the real children run, but the orphaned copies are never pruned.
set -euo pipefail
source "$AM_LIB"

am_argocd app set billing-root --dest-namespace argocd
am_wait_app billing-root sync=OutOfSync --timeout 60
# sync without --prune: the children appear, the orphans stay
am_argocd app sync billing-root --timeout 120 || true   # exits 20: 2 resources require pruning
am_wait_app invoice-api sync=Synced health=Healthy --timeout 150
am_wait_app dunning-worker sync=Synced health=Healthy --timeout 150

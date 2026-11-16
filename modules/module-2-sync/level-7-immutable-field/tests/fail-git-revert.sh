#!/bin/bash
# Wrong: revert the relabel commit. The app syncs, but Git no longer has the new selector.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/ticket-desk"
git revert --no-edit HEAD >/dev/null
git push -q origin HEAD
am_app_refresh ticket-desk
am_wait_app ticket-desk sync=OutOfSync --timeout 60 || true
am_argocd app sync ticket-desk --timeout 120
am_wait_app ticket-desk sync=Synced health=Healthy --timeout 120

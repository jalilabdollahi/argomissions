#!/bin/bash
# Wrong: revert the labels commit. The app syncs again, but the requested labels are gone.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/ledger-api"
git revert --no-edit HEAD >/dev/null
git push -q origin HEAD
am_argocd app get ledger-api --refresh >/dev/null
am_argocd app sync ledger-api --timeout 120
am_wait_app ledger-api sync=Synced health=Healthy --timeout 120

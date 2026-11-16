#!/bin/bash
# Wrong: delete the Deployment so the wider selector can be created. It syncs, but the selector is now
# {app, team, cost-center} and the service had a gap.
set -euo pipefail
source "$AM_LIB"

kubectl -n ledger delete deploy ledger-api --wait=true
am_argocd app sync ledger-api --timeout 120
am_wait_app ledger-api sync=Synced health=Healthy --timeout 120

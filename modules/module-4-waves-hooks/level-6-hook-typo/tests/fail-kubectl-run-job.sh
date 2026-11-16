#!/bin/bash
# Wrong: run the Job by hand. The index is rebuilt, but not as a hook of a sync, and Git still has the typo.
set -euo pipefail
source "$AM_LIB"

sed 's/hook: PreSynk/hook: PreSync/' "$SANDBOX/ticket-desk/deploy/reindex-job.yaml" | kubectl apply -n helpdesk -f -
kubectl -n helpdesk wait --for=condition=complete job/reindex-tickets --timeout=90s

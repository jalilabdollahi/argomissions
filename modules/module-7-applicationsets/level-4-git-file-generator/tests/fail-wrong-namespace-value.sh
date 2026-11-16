#!/bin/bash
# Wrong: the key is fixed, but globex is pointed at another namespace than tenant-globex.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/tenant-stack"
"$AM_PYTHON" - tenants/globex/config.json <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace('"nameSpace": "tenant-globex"', '"namespace": "globex-prod"')
open(p, "w").write(s)
PY
am_player_push "$SANDBOX/tenant-stack" "globex: fix the namespace key"
# the repo-server caches the branch lookup for up to 60s: nudge the set until it sees the push
for i in $(seq 1 12); do
  kubectl -n argocd annotate applicationset tenant-portals argocd.argoproj.io/application-set-refresh=true --overwrite >/dev/null
  am_wait 20 bash -c 'kubectl -n argocd get applicationset tenant-portals -o json | jq -e "[.status.conditions[]? | select(.type==\"ErrorOccurred\" and .status==\"True\")] | length == 0"' && break
done
am_wait_app tenant-globex sync=Synced health=Healthy --timeout 200

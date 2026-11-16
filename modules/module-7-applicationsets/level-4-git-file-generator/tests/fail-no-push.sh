#!/bin/bash
# Wrong: the file is corrected in the workspace clone but never committed and pushed.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/tenant-stack"
"$AM_PYTHON" - tenants/globex/config.json <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace('"nameSpace"', '"namespace"')
open(p, "w").write(s)
PY
kubectl -n argocd annotate applicationset tenant-portals argocd.argoproj.io/application-set-refresh=true --overwrite >/dev/null
sleep 20

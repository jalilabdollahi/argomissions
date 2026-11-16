#!/bin/bash
set -euo pipefail
source "$AM_LIB"

"$AM_PYTHON" - "$SANDBOX/harbor-appset.yaml" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("{{path.basename}}", "{{.path.basename}}").replace("'{{path}}'", "'{{.path.path}}'")
open(p, "w").write(s)
PY
kubectl apply -f "$SANDBOX/harbor-appset.yaml"
for s in dock-api dock-tracker dock-notify; do
  am_wait_app "$s" sync=Synced health=Healthy --timeout 150
done

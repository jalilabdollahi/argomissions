#!/bin/bash
set -euo pipefail
source "$AM_LIB"

"$AM_PYTHON" - "$SANDBOX/mesh-appset.yaml" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("      name: '{{.path.basename}}'\n", "      name: '{{.path.basename}}-{{.env}}'\n")
open(p, "w").write(s)
PY
kubectl apply -f "$SANDBOX/mesh-appset.yaml"
for a in invoicer-staging invoicer-prod mailer-staging mailer-prod; do
  am_wait_app "$a" sync=Synced health=Healthy --timeout 150
done

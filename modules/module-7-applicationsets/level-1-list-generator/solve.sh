#!/bin/bash
set -euo pipefail
source "$AM_LIB"

"$AM_PYTHON" - "$SANDBOX/geo-edge-appset.yaml" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("      - region: ap-south\n", "      - region: ap-south\n      - region: eu-west\n")
open(p, "w").write(s)
PY
kubectl apply -f "$SANDBOX/geo-edge-appset.yaml"
am_wait_app geo-edge-eu-west sync=Synced health=Healthy --timeout 150

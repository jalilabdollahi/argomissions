#!/bin/bash
# Wrong: an exclude entry whose path does not match the folder (missing the apps/ prefix).
set -euo pipefail
source "$AM_LIB"

"$AM_PYTHON" - "$SANDBOX/studio-appset.yaml" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("      - path: apps/*\n", "      - path: apps/*\n      - path: shared\n        exclude: true\n")
open(p, "w").write(s)
PY
kubectl apply -f "$SANDBOX/studio-appset.yaml"
sleep 30

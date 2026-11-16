#!/bin/bash
set -euo pipefail
source "$AM_LIB"

"$AM_PYTHON" - "$SANDBOX/studio-appset.yaml" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("      - path: apps/*\n", "      - path: apps/*\n      - path: apps/shared\n        exclude: true\n")
open(p, "w").write(s)
PY
kubectl apply -f "$SANDBOX/studio-appset.yaml"
am_wait 120 bash -c '! kubectl -n argocd get application studio-shared' || { echo "studio-shared still exists"; exit 1; }
am_wait 60 bash -c '! kubectl -n studio get configmap studio-defaults' || { echo "configmap still exists"; exit 1; }

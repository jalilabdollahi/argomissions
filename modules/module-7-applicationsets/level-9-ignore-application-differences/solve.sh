#!/bin/bash
set -euo pipefail
source "$AM_LIB"

"$AM_PYTHON" - "$SANDBOX/feedhub-appset.yaml" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("spec:\n  goTemplate: true\n",
    "spec:\n  ignoreApplicationDifferences:\n  - jsonPointers:\n    - /spec/source/targetRevision\n  goTemplate: true\n", 1)
open(p, "w").write(s)
PY
kubectl apply -f "$SANDBOX/feedhub-appset.yaml"
sleep 3
am_argocd app set feedhub-prod --revision hotfix-1.8.1
am_wait_app feedhub-prod sync=Synced health=Healthy --timeout 150

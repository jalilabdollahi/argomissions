#!/bin/bash
set -euo pipefail
source "$AM_LIB"

"$AM_PYTHON" - "$SANDBOX/lumen-appset.yaml" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().rstrip("\n") + '''
  templatePatch: |
    {{- if eq .env "prod" }}
    spec:
      syncPolicy:
        automated:
          prune: true
    {{- end }}
'''
open(p, "w").write(s)
PY
kubectl apply -f "$SANDBOX/lumen-appset.yaml"
am_wait_app lumen-prod sync=Synced health=Healthy --timeout 150

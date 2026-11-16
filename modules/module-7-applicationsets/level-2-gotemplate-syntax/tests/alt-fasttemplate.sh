#!/bin/bash
# Correct too: keep the original templates and switch goTemplate off (the {{path.basename}} syntax is valid there).
set -euo pipefail
source "$AM_LIB"

"$AM_PYTHON" - "$SANDBOX/harbor-appset.yaml" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("  goTemplate: true\n", "").replace('  goTemplateOptions: ["missingkey=error"]\n', "")
open(p, "w").write(s)
PY
kubectl apply -f "$SANDBOX/harbor-appset.yaml"
for s in dock-api dock-tracker dock-notify; do
  am_wait_app "$s" sync=Synced health=Healthy --timeout 150
done

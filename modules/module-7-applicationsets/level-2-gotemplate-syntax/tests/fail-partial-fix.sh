#!/bin/bash
# Wrong: only the Application name was converted to Go syntax; `path:` still uses the old form.
set -euo pipefail
source "$AM_LIB"

"$AM_PYTHON" - "$SANDBOX/harbor-appset.yaml" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("{{path.basename}}", "{{.path.basename}}")
open(p, "w").write(s)
PY
kubectl apply -f "$SANDBOX/harbor-appset.yaml"
sleep 20

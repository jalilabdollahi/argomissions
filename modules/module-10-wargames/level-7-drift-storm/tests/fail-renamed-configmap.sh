#!/bin/bash
# Wrong: the self-heal and the ignore rule are right, but the duplicate ConfigMap is "solved" by renaming alerts' copy.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
cd "$SANDBOX/stormwatch"; git pull -q
"$AM_PYTHON" - <<'PY'
p = "apps/ingest.yaml"
s = open(p).read()
s = s.replace("  syncPolicy:\n    automated:\n      prune: true\n",
              "  ignoreDifferences:\n  - group: apps\n    kind: Deployment\n    jqPathExpressions:\n    - '.metadata.annotations[\"mesh.argomissions.io/epoch\"]'\n"
              "  syncPolicy:\n    automated:\n      prune: true\n      selfHeal: true\n")
open(p, "w").write(s)
p = "workloads/alerts/thresholds.yaml"
s = open(p).read().replace("name: thresholds", "name: alert-thresholds")
open(p, "w").write(s)
PY
finish "storm night: ignore the mesh stamp, self-heal, separate alert thresholds"

#!/bin/bash
# Correct too: sw-alerts keeps `thresholds` (with both keys), the ignore rule uses the field pointer, and the pin is
# removed by editing the live child and syncing the root.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
cd "$SANDBOX/stormwatch"; git pull -q
"$AM_PYTHON" - <<'PY'
p = "apps/ingest.yaml"
s = open(p).read()
s = s.replace("  syncPolicy:\n    automated:\n      prune: true\n",
              "  ignoreDifferences:\n  - group: apps\n    kind: Deployment\n    jsonPointers:\n    - /metadata/annotations/mesh.argomissions.io~1epoch\n"
              "  syncPolicy:\n    automated:\n      prune: true\n      selfHeal: true\n")
open(p, "w").write(s)
p = "workloads/alerts/thresholds.yaml"
s = open(p).read().rstrip("\n") + "\n  rain_mm: \"40\"\n"
open(p, "w").write(s)
PY
git rm -q workloads/ingest/thresholds.yaml
finish "storm night: alerts owns thresholds, ignore the mesh stamp, self-heal"

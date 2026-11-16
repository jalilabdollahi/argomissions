#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/payroll-api"
am_argocd app diff payroll-api || true
"$AM_PYTHON" - <<'PY'
import re, pathlib
p = pathlib.Path("deploy/migrate-job.yaml")
t = p.read_text()
t = t.replace("  name: payroll-schema-migrate\n", "  name: payroll-schema-migrate\n  annotations:\n    argocd.argoproj.io/hook: PreSync\n", 1)
p.write_text(t)
PY
am_player_push . "run the schema migration as a PreSync hook"
am_app_refresh payroll-api
am_wait_app payroll-api sync=OutOfSync rev="$(am_repo_head payroll-api)" --timeout 90
am_argocd app sync payroll-api --timeout 150
am_argocd app wait payroll-api --health --timeout 120

#!/bin/bash
# Correct too: no hook, but a lower sync wave on the Job. Argo CD waits for the Job to be Healthy
# (completed) before it starts the next wave.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/payroll-api"
"$AM_PYTHON" - <<'PY'
import pathlib
p = pathlib.Path("deploy/migrate-job.yaml")
t = p.read_text()
t = t.replace("  name: payroll-schema-migrate\n", "  name: payroll-schema-migrate\n  annotations:\n    argocd.argoproj.io/sync-wave: \"-1\"\n", 1)
p.write_text(t)
PY
am_player_push . "migration job in wave -1"
am_app_refresh payroll-api
am_wait_app payroll-api sync=OutOfSync rev="$(am_repo_head payroll-api)" --timeout 90
am_argocd app sync payroll-api --timeout 150
am_wait_app payroll-api sync=Synced health=Healthy op=Succeeded --timeout 120

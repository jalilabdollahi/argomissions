#!/bin/bash
# Correct too: no RBAC hooks; waves inside the Sync phase: RBAC -2, migration Job (a Sync hook) -1, Deployment 0.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/payroll-engine"
"$AM_PYTHON" - <<'PY'
p = "deploy/rbac.yaml"
s = open(p).read()
ann = "  annotations:\n    argocd.argoproj.io/sync-wave: \"-2\"\n"
for kind in ("Role", "RoleBinding"):
    s = s.replace(f"kind: {kind}\nmetadata:\n  name: migrator\n", f"kind: {kind}\nmetadata:\n  name: migrator\n{ann}")
open(p, "w").write(s)
p = "deploy/migrate-job.yaml"
s = open(p).read()
s = s.replace("hook: PreSync\n", "hook: Sync\n    argocd.argoproj.io/sync-wave: \"-1\"\n")
open(p, "w").write(s)
PY
am_player_push . "waves: RBAC -2, migration -1, deployment 0"
head="$(am_repo_head payroll-engine)"
am_app_refresh payroll-engine
am_wait_app payroll-engine rev="$head" --timeout 120
am_argocd app sync payroll-engine --timeout 180
am_wait_app payroll-engine op=Succeeded sync=Synced health=Healthy --timeout 120

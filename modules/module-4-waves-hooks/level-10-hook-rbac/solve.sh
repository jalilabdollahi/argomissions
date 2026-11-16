#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app get payroll-engine --show-operation || true
kubectl -n payroll logs job/ledger-migrate || true
cd "$SANDBOX/payroll-engine"
git pull -q
# Role and RoleBinding become PreSync hooks in an earlier wave than the migration Job.
"$AM_PYTHON" - <<'PY'
import re
p = "deploy/rbac.yaml"
s = open(p).read()
hook = ("  annotations:\n    argocd.argoproj.io/hook: PreSync\n    argocd.argoproj.io/sync-wave: \"-1\"\n"
        "    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation\n")
for kind in ("Role", "RoleBinding"):
    s = s.replace(f"kind: {kind}\nmetadata:\n  name: migrator\n", f"kind: {kind}\nmetadata:\n  name: migrator\n{hook}")
open(p, "w").write(s)
PY
am_player_push . "migrator RBAC: PreSync hooks in an earlier wave than the migration"
head="$(am_repo_head payroll-engine)"
am_app_refresh payroll-engine
am_wait_app payroll-engine rev="$head" --timeout 120
am_argocd app sync payroll-engine --timeout 180
am_argocd app wait payroll-engine --health --timeout 120

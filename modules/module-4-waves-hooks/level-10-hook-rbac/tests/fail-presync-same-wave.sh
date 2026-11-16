#!/bin/bash
# Wrong (partial): RBAC becomes PreSync hooks, but in the same wave as the Job: they start together.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/payroll-engine"
"$AM_PYTHON" - <<'PY'
p = "deploy/rbac.yaml"
s = open(p).read()
hook = "  annotations:\n    argocd.argoproj.io/hook: PreSync\n    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation\n"
for kind in ("Role", "RoleBinding"):
    s = s.replace(f"kind: {kind}\nmetadata:\n  name: migrator\n", f"kind: {kind}\nmetadata:\n  name: migrator\n{hook}")
open(p, "w").write(s)
PY
am_player_push . "migrator RBAC as PreSync hooks"
head="$(am_repo_head payroll-engine)"
am_app_refresh payroll-engine
am_wait_app payroll-engine rev="$head" --timeout 120
am_argocd app sync payroll-engine --timeout 180 || true
am_wait 60 bash -c "[ \"\$(source '$AM_LIB'; am_app_op payroll-engine)\" != Running ]"

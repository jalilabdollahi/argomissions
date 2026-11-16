#!/bin/bash
# Wrong: the permanent OutOfSync of the ShiftPolicy is hidden with ignoreDifferences instead of updating the CRD.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/shiftboard"
git pull -q
sed -i.bak 's/hook-delete-policy: HookFailed/hook-delete-policy: BeforeHookCreation/' deploy/migrate-job.yaml && rm -f deploy/migrate-job.yaml.bak
"$AM_PYTHON" - <<'PY'
p = "deploy/rbac.yaml"
s = open(p).read()
hook = ("  annotations:\n    argocd.argoproj.io/hook: PreSync\n    argocd.argoproj.io/sync-wave: \"-1\"\n"
        "    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation\n")
for kind in ("ServiceAccount", "Role", "RoleBinding"):
    s = s.replace(f"kind: {kind}\nmetadata:\n  name: rota-migrator\n", f"kind: {kind}\nmetadata:\n  name: rota-migrator\n{hook}")
open(p, "w").write(s)
PY
sed -i.bak 's#http://shiftboard-api/#http://shiftboard/#' deploy/smoke-test.yaml && rm -f deploy/smoke-test.yaml.bak
am_player_push . "release v7: fixes"
head="$(am_repo_head shiftboard)"
am_app_refresh shiftboard
am_wait_app shiftboard rev="$head" --timeout 120
am_argocd app patch shiftboard --type merge --patch '{"spec":{"ignoreDifferences":[{"group":"rostering.argomissions.io","kind":"ShiftPolicy","jsonPointers":["/spec/restDays"]}]}}'
am_argocd app sync shiftboard --timeout 240
am_wait_app shiftboard sync=Synced health=Healthy op=Succeeded --timeout 150

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app get shiftboard --show-operation || true
cd "$SANDBOX/shiftboard"
git pull -q

# 1. the migration Job must be cleared away before the next run creates it
sed -i.bak 's/hook-delete-policy: HookFailed/hook-delete-policy: BeforeHookCreation/' deploy/migrate-job.yaml && rm -f deploy/migrate-job.yaml.bak
# 2. the migrator's identity and permissions exist before the migration runs
"$AM_PYTHON" - <<'PY'
p = "deploy/rbac.yaml"
s = open(p).read()
hook = ("  annotations:\n    argocd.argoproj.io/hook: PreSync\n    argocd.argoproj.io/sync-wave: \"-1\"\n"
        "    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation\n")
for kind in ("ServiceAccount", "Role", "RoleBinding"):
    s = s.replace(f"kind: {kind}\nmetadata:\n  name: rota-migrator\n", f"kind: {kind}\nmetadata:\n  name: rota-migrator\n{hook}")
open(p, "w").write(s)
PY
# 4. the smoke test calls the Service that exists
sed -i.bak 's#http://shiftboard-api/#http://shiftboard/#' deploy/smoke-test.yaml && rm -f deploy/smoke-test.yaml.bak
am_player_push . "release v7: migration cleanup, RBAC before migration, CRD before policy, smoke test on the real Service"
head="$(am_repo_head shiftboard)"
# 3. the CRD must follow Git by itself, ahead of the release
am_argocd app set rota-crds --sync-policy automated
am_app_refresh rota-crds
am_wait_app rota-crds sync=Synced health=Healthy rev="$head" --timeout 120
am_app_refresh shiftboard
am_wait_app shiftboard rev="$head" --timeout 120
am_argocd app sync shiftboard --timeout 240
am_argocd app wait shiftboard --health --timeout 120

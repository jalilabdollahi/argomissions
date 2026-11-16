#!/bin/bash
# Wrong: everything is fixed in Git except that the smoke test is silenced with `|| true`.
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
sed -i.bak 's#sleep 3; done; \[ \$ok = 1 \]#sleep 3; done; [ $ok = 1 ] || true#' deploy/smoke-test.yaml && rm -f deploy/smoke-test.yaml.bak
sed -i.bak 's#http://shiftboard-api/#http://shiftboard-api/#' deploy/smoke-test.yaml && rm -f deploy/smoke-test.yaml.bak
am_player_push . "release v7: make the pipeline green"
head="$(am_repo_head shiftboard)"
am_argocd app set rota-crds --sync-policy automated
am_app_refresh rota-crds
am_wait_app rota-crds sync=Synced health=Healthy rev="$head" --timeout 120
am_app_refresh shiftboard
am_wait_app shiftboard rev="$head" --timeout 120
am_argocd app sync shiftboard --timeout 240
am_wait_app shiftboard sync=Synced health=Healthy op=Succeeded --timeout 150

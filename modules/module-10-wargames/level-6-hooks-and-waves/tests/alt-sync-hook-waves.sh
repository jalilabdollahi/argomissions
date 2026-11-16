#!/bin/bash
# Correct too: the RBAC stays a regular resource; the migration becomes a Sync-phase hook in a wave after it and
# the Deployment rolls out after the migration.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/shiftboard"
git pull -q
"$AM_PYTHON" - <<'PY'
p = "deploy/migrate-job.yaml"
s = open(p).read()
s = s.replace("    argocd.argoproj.io/hook: PreSync\n    argocd.argoproj.io/hook-delete-policy: HookFailed\n",
              "    argocd.argoproj.io/hook: Sync\n    argocd.argoproj.io/sync-wave: \"5\"\n    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation\n")
open(p, "w").write(s)
p = "deploy/deployment.yaml"
s = open(p).read()
s = s.replace("kind: Deployment\nmetadata:\n  name: shiftboard\n", "kind: Deployment\nmetadata:\n  name: shiftboard\n  annotations:\n    argocd.argoproj.io/sync-wave: \"6\"\n", 1)
open(p, "w").write(s)
PY
sed -i.bak 's#http://shiftboard-api/#http://shiftboard/#' deploy/smoke-test.yaml && rm -f deploy/smoke-test.yaml.bak
am_player_push . "release v7: migration after RBAC (waves), real smoke test"
head="$(am_repo_head shiftboard)"
am_argocd app set rota-crds --sync-policy automated
am_app_refresh rota-crds
am_wait_app rota-crds sync=Synced health=Healthy rev="$head" --timeout 120
am_app_refresh shiftboard
am_wait_app shiftboard rev="$head" --timeout 120
am_argocd app sync shiftboard --timeout 240
am_wait_app shiftboard sync=Synced health=Healthy op=Succeeded --timeout 150

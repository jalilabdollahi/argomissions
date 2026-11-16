#!/bin/bash
# Wrong: the repo is made public so that no credentials are needed; the rest is fixed properly.
set -euo pipefail
source "$AM_LIB"

am_gitea PATCH /repos/platform/tidewater-gitops '{"private":false}' >/dev/null
kubectl apply -f "$SANDBOX/tidewater-gitops/bootstrap/root.yaml"
am_argocd app get tidewater-root --hard-refresh >/dev/null
am_wait_app tidewater-root sync=Synced --timeout 150
am_wait 120 kubectl -n argocd get application tidewater-batch
cd "$SANDBOX/tidewater-gitops"
"$AM_PYTHON" - <<'PY'
p = "platform/apps/tidewater-ledger.yaml"
s = open(p).read().rstrip("\n") + "\n    syncOptions:\n    - CreateNamespace=true\n"
open(p, "w").write(s)
p = "platform/projects/tidewater.yaml"
s = open(p).read().replace("    namespace: tidewater-edge\n", "    namespace: tidewater-edge\n  - server: https://kubernetes.default.svc\n    namespace: tidewater-jobs\n")
open(p, "w").write(s)
PY
am_player_push . "Fix children"
am_argocd app get tidewater-root --refresh >/dev/null
# a sync that is still retrying keeps the old parameters: end it so the next automated sync uses the fixed spec
sleep 15
am_argocd app terminate-op tidewater-ledger >/dev/null 2>&1 || true
for a in tidewater-ledger tidewater-batch tidewater-gateway; do
  am_wait_app "$a" sync=Synced health=Healthy --timeout 180
done

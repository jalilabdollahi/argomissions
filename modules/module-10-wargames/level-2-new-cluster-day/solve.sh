#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# 1. Argo CD needs credentials for the private repo (the read-only machine user from the handoff)
am_argocd repo add "$(am_repo_url tidewater-gitops)" --username tidewater-reader --password reader-pass-4Kd9
# 2. bootstrap: the root Application from the repo's runbook
kubectl apply -f "$SANDBOX/tidewater-gitops/bootstrap/root.yaml"
am_argocd app get tidewater-root --hard-refresh >/dev/null
am_wait_app tidewater-root sync=Synced --timeout 150
am_wait 120 kubectl -n argocd get application tidewater-batch

# 3. both child problems are fixed in Git, the root applies them
cd "$SANDBOX/tidewater-gitops"
"$AM_PYTHON" - <<'PY'
p = "platform/apps/tidewater-ledger.yaml"
s = open(p).read().rstrip("\n") + "\n    syncOptions:\n    - CreateNamespace=true\n"
open(p, "w").write(s)
p = "platform/projects/tidewater.yaml"
s = open(p).read().replace("    namespace: tidewater-edge\n", "    namespace: tidewater-edge\n  - server: https://kubernetes.default.svc\n    namespace: tidewater-jobs\n")
open(p, "w").write(s)
PY
am_player_push . "Create the ledger namespace, allow tidewater-jobs in the project"
am_argocd app get tidewater-root --refresh >/dev/null
# a sync that is still retrying keeps the old parameters: end it so the next automated sync uses the fixed spec
sleep 15
am_argocd app terminate-op tidewater-ledger >/dev/null 2>&1 || true
am_wait_app tidewater-root sync=Synced rev="$(am_repo_head tidewater-gitops)" --timeout 150
for a in tidewater-ledger tidewater-batch tidewater-gateway; do
  am_argocd app get "$a" --refresh >/dev/null
  am_wait_app "$a" sync=Synced health=Healthy --timeout 180
done
am_wait_app tidewater-root sync=Synced health=Healthy --timeout 120

#!/bin/bash
# Wrong: the missing namespace is created with kubectl instead of in Git (this is what on-call did); a rebuild fails again.
set -euo pipefail
source "$AM_LIB"

am_argocd repo add "$(am_repo_url tidewater-gitops)" --username tidewater-reader --password reader-pass-4Kd9
kubectl apply -f "$SANDBOX/tidewater-gitops/bootstrap/root.yaml"
am_argocd app get tidewater-root --hard-refresh >/dev/null
am_wait_app tidewater-root sync=Synced --timeout 150
am_wait 120 kubectl -n argocd get application tidewater-batch
kubectl create namespace tidewater-ledger
cd "$SANDBOX/tidewater-gitops"
"$AM_PYTHON" - <<'PY'
p = "platform/projects/tidewater.yaml"
s = open(p).read().replace("    namespace: tidewater-edge\n", "    namespace: tidewater-edge\n  - server: https://kubernetes.default.svc\n    namespace: tidewater-jobs\n")
open(p, "w").write(s)
PY
am_player_push . "Allow tidewater-jobs"
am_argocd app get tidewater-root --refresh >/dev/null
# a sync that is still retrying keeps the old parameters: end it so the next automated sync uses the fixed spec
sleep 15
am_argocd app terminate-op tidewater-ledger >/dev/null 2>&1 || true
for a in tidewater-ledger tidewater-batch tidewater-gateway; do
  am_argocd app get "$a" --refresh >/dev/null
  am_argocd app sync "$a" --timeout 120 >/dev/null || true
  am_wait_app "$a" sync=Synced health=Healthy --timeout 180
done

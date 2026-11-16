#!/bin/bash
# Correct too: the repository declared as a labelled Secret, the namespace for the ledger created by a Namespace
# manifest in Git, the project fixed with a namespace pattern for the platform.
set -euo pipefail
source "$AM_LIB"

kubectl apply -f - <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: repo-tidewater-gitops
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: $(am_repo_url tidewater-gitops)
  username: tidewater-reader
  password: reader-pass-4Kd9
YAML
kubectl apply -f "$SANDBOX/tidewater-gitops/bootstrap/root.yaml"
am_argocd app get tidewater-root --hard-refresh >/dev/null
am_wait_app tidewater-root sync=Synced --timeout 150
am_wait 120 kubectl -n argocd get application tidewater-batch
cd "$SANDBOX/tidewater-gitops"
cat > workloads/ledger/namespace.yaml <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: tidewater-ledger
YAML
"$AM_PYTHON" - <<'PY'
p = "platform/projects/tidewater.yaml"
s = open(p).read().replace("    namespace: tidewater-ledger\n", "    namespace: tidewater-*\n").replace("  - server: https://kubernetes.default.svc\n    namespace: tidewater-edge\n", "")
open(p, "w").write(s)
PY
am_player_push . "Namespace manifest for the ledger, project allows tidewater-*"
am_argocd app get tidewater-root --refresh >/dev/null
# a sync that is still retrying keeps the old parameters: end it so the next automated sync uses the fixed spec
sleep 15
am_argocd app terminate-op tidewater-ledger >/dev/null 2>&1 || true
for a in tidewater-ledger tidewater-batch tidewater-gateway; do
  am_argocd app get "$a" --refresh >/dev/null
  am_wait_app "$a" sync=Synced health=Healthy --timeout 180
done

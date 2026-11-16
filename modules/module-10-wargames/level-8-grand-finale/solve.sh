#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app get meridian-root || true
kubectl -n argocd get applicationset meridian-edge -o jsonpath='{.status.conditions[*].message}{"\n"}' || true
am_argocd app get meridian-core || true
cd "$SANDBOX/meridian-platform"
git pull -q
# projects: into the folder the root reads, ahead of their users; the edge project admits harbor too
git mv bootstrap/projects/meridian-core.yaml bootstrap/meridian-core-project.yaml
git mv bootstrap/projects/meridian-edge.yaml bootstrap/meridian-edge-project.yaml
"$AM_PYTHON" - <<'PY'
for p in ("bootstrap/meridian-core-project.yaml", "bootstrap/meridian-edge-project.yaml"):
    s = open(p).read()
    s = s.replace("  namespace: argocd\n", "  namespace: argocd\n  annotations:\n    argocd.argoproj.io/sync-wave: \"-1\"\n", 1)
    if "edge" in p:
        s = s.replace("    namespace: meridian-south\n", "    namespace: meridian-south\n  - server: https://kubernetes.default.svc\n    namespace: meridian-harbor\n")
    open(p, "w").write(s)
p = "bootstrap/edge-appset.yaml"
s = open(p).read().replace("{{district}}", "{{.district}}")
open(p, "w").write(s)
p = "bootstrap/core.yaml"
s = open(p).read().replace("    automated: {}\n", "    automated: {}\n    syncOptions:\n    - CreateNamespace=true\n")
open(p, "w").write(s)
PY
sed -i.bak 's#http://meridian-core:8080/#http://meridian-core/#' core/smoke-test.yaml && rm -f core/smoke-test.yaml.bak
am_player_push . "bootstrap: projects first, edge project admits harbor, appset go-template syntax, core namespace, smoke test port"
head="$(am_repo_head meridian-platform)"
am_app_refresh meridian-root
am_wait_app meridian-root rev="$head" sync=Synced --timeout 150
kubectl -n argocd annotate applicationset meridian-edge argocd.argoproj.io/application-set-refresh=true --overwrite >/dev/null || true
for d in north south harbor; do am_wait 120 bash -c "kubectl -n argocd get application meridian-edge-$d" ; done
for a in meridian-core meridian-edge-north meridian-edge-south meridian-edge-harbor; do am_app_refresh "$a"; done
for a in meridian-edge-north meridian-edge-south meridian-edge-harbor meridian-core meridian-root; do
  am_wait_app "$a" sync=Synced health=Healthy rev="$head" --timeout 200
done
sleep 5

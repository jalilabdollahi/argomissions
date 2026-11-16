# shellcheck shell=bash
# Shared by the tests of this level. fix_git applies the correct Git fixes; flags break one part on purpose:
#   NO_WAVE=1 (projects without sync-wave)  WILDCARD=1 (edge project destination '*')  SWALLOW=1 (smoke test || true)
#   KEEP_SUBDIR=1 (projects stay in bootstrap/projects)
fix_git() {
  cd "$SANDBOX/meridian-platform"; git pull -q
  if [ -z "${KEEP_SUBDIR:-}" ]; then
    git mv bootstrap/projects/meridian-core.yaml bootstrap/meridian-core-project.yaml
    git mv bootstrap/projects/meridian-edge.yaml bootstrap/meridian-edge-project.yaml
    PROJ="bootstrap/meridian-core-project.yaml bootstrap/meridian-edge-project.yaml"
  else
    PROJ="bootstrap/projects/meridian-core.yaml bootstrap/projects/meridian-edge.yaml"
  fi
  PROJ="$PROJ" "$AM_PYTHON" - <<'PY'
import os
for p in os.environ["PROJ"].split():
    s = open(p).read()
    if not os.environ.get("NO_WAVE"):
        s = s.replace("  namespace: argocd\n", "  namespace: argocd\n  annotations:\n    argocd.argoproj.io/sync-wave: \"-1\"\n", 1)
    if "edge" in p:
        if os.environ.get("WILDCARD"):
            s = s.replace("    namespace: meridian-south\n", "    namespace: '*'\n")
        else:
            s = s.replace("    namespace: meridian-south\n", "    namespace: meridian-south\n  - server: https://kubernetes.default.svc\n    namespace: meridian-harbor\n")
    open(p, "w").write(s)
p = "bootstrap/edge-appset.yaml"
s = open(p).read().replace("{{district}}", "{{.district}}")
open(p, "w").write(s)
p = "bootstrap/core.yaml"
s = open(p).read().replace("    automated: {}\n", "    automated: {}\n    syncOptions:\n    - CreateNamespace=true\n")
open(p, "w").write(s)
PY
  if [ -n "${SWALLOW:-}" ]; then
    sed -i.bak "s#curl -fsS --max-time 5 http://meridian-core:8080/ | grep -q 'meridian-core'#curl -fsS --max-time 5 http://meridian-core/ | grep -q 'meridian-core' || true#" core/smoke-test.yaml
  else
    sed -i.bak 's#http://meridian-core:8080/#http://meridian-core/#' core/smoke-test.yaml
  fi
  rm -f core/smoke-test.yaml.bak
}
finish() {
  am_player_push . "$1"
  local head; head="$(am_repo_head meridian-platform)"
  am_app_refresh meridian-root
  am_wait_app meridian-root rev="$head" --timeout 150
  kubectl -n argocd annotate applicationset meridian-edge argocd.argoproj.io/application-set-refresh=true --overwrite >/dev/null || true
  for d in north south harbor; do am_wait 120 bash -c "kubectl -n argocd get application meridian-edge-$d"; done
  for a in meridian-core meridian-edge-north meridian-edge-south meridian-edge-harbor; do am_app_refresh "$a"; done
  for a in meridian-edge-north meridian-edge-south meridian-edge-harbor meridian-core meridian-root; do
    am_wait_app "$a" sync=Synced health=Healthy rev="$head" --timeout 200
  done
  sleep 5
}

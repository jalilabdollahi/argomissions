# shellcheck shell=bash
# Shared by the tests of this level: one function per correct fix.
git_edit_all() {   # ignore rule + self-heal + one ConfigMap owner (ingest keeps it)
  cd "$SANDBOX/stormwatch"; git pull -q
  "$AM_PYTHON" - <<'PY'
p = "apps/ingest.yaml"
s = open(p).read()
s = s.replace("  syncPolicy:\n    automated:\n      prune: true\n",
              "  ignoreDifferences:\n  - group: apps\n    kind: Deployment\n    jqPathExpressions:\n    - '.metadata.annotations[\"mesh.argomissions.io/epoch\"]'\n"
              "  syncPolicy:\n    automated:\n      prune: true\n      selfHeal: true\n")
open(p, "w").write(s)
p = "workloads/ingest/thresholds.yaml"
s = open(p).read().rstrip("\n") + "\n  wind_kmh: \"90\"\n"
open(p, "w").write(s)
PY
  git rm -q workloads/alerts/thresholds.yaml
}
finish() {   # push, root heals, wait for everything
  am_player_push . "$1"
  local head; head="$(am_repo_head stormwatch)"
  am_argocd app set stormwatch-root --sync-policy automated --self-heal
  for a in stormwatch-root sw-ingest sw-alerts; do am_app_refresh "$a"; done
  am_wait_app stormwatch-root rev="$head" --timeout 120
  am_argocd app sync stormwatch-root --timeout 120 || true
  for a in sw-ingest sw-alerts stormwatch-root; do am_app_refresh "$a"; done
  for a in sw-ingest sw-alerts stormwatch-root; do am_wait_app "$a" sync=Synced health=Healthy rev="$head" --timeout 180; done
  sleep 5
}

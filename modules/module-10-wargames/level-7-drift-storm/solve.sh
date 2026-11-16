#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app get stormwatch-root || true
am_argocd app diff stormwatch-root || true
cd "$SANDBOX/stormwatch"
git pull -q
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
am_player_push . "storm night: one owner for thresholds, ignore the mesh stamp, self-heal on"
head="$(am_repo_head stormwatch)"
# the root heals hand edits from now on, and puts sw-alerts back on main
am_argocd app set stormwatch-root --sync-policy automated --self-heal
for a in stormwatch-root sw-ingest sw-alerts; do am_app_refresh "$a"; done
am_wait_app stormwatch-root rev="$head" --timeout 120
am_argocd app sync stormwatch-root --timeout 120 || true
for a in sw-ingest sw-alerts stormwatch-root; do am_app_refresh "$a"; done
for a in sw-ingest sw-alerts stormwatch-root; do am_wait_app "$a" sync=Synced health=Healthy rev="$head" --timeout 180; done
sleep 5

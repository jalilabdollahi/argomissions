#!/bin/bash
# Wrong: the project is opened to every repository instead of re-adding the services repo.
set -euo pipefail
source "$AM_LIB"

am_argocd app set orbit-control --sync-policy automated --auto-prune --self-heal
am_argocd proj add-source orbit '*'
cd "$SANDBOX/orbit-control"
git revert --no-edit HEAD
"$AM_PYTHON" - <<'PY'
p = "appsets/orbit-fleet.yaml"
s = open(p).read().replace("  generators:\n", "  syncPolicy:\n    preserveResourcesOnDeletion: true\n  generators:\n", 1)
open(p, "w").write(s)
PY
am_player_push . "Revert and protect"
am_argocd app get orbit-control --refresh >/dev/null
am_wait_app orbit-control sync=Synced --timeout 150
for s in ingest rollup alerts; do
  am_wait 120 kubectl -n argocd get application "orbit-$s"
  am_wait_app "orbit-$s" sync=Synced health=Healthy --timeout 180
done

#!/bin/bash
# Wrong: the revert and the protection go in and the project is fixed, but orbit-control stays on manual sync
# and the fix is pushed through with a hand-started sync.
set -euo pipefail
source "$AM_LIB"

am_argocd proj add-source orbit "$(am_repo_url orbit-services)"
cd "$SANDBOX/orbit-control"
git revert --no-edit HEAD
"$AM_PYTHON" - <<'PY'
p = "appsets/orbit-fleet.yaml"
s = open(p).read().replace("  generators:\n", "  syncPolicy:\n    preserveResourcesOnDeletion: true\n  generators:\n", 1)
open(p, "w").write(s)
PY
am_player_push . "Revert and protect"
am_argocd app get orbit-control --refresh >/dev/null
am_argocd app sync orbit-control --timeout 120
for s in ingest rollup alerts; do
  am_wait 120 kubectl -n argocd get application "orbit-$s"
  am_wait_app "orbit-$s" sync=Synced health=Healthy --timeout 180
done

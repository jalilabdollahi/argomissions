#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# on-call paused the automation of orbit-control: switch it back on, and let the project read the services repo again
am_argocd app set orbit-control --sync-policy automated --auto-prune --self-heal
am_argocd proj add-source orbit "$(am_repo_url orbit-services)"

cd "$SANDBOX/orbit-control"
git log --oneline
git revert --no-edit HEAD
"$AM_PYTHON" - <<'PY'
p = "appsets/orbit-fleet.yaml"
s = open(p).read().replace("  generators:\n", "  syncPolicy:\n    preserveResourcesOnDeletion: true\n  generators:\n", 1)
open(p, "w").write(s)
PY
am_player_push . "Protect the fleet: no cascade when an Application or the set is deleted"
am_argocd app get orbit-control --refresh >/dev/null
am_wait_app orbit-control sync=Synced health=Healthy rev="$(am_repo_head orbit-control)" --timeout 150
for s in ingest rollup alerts; do
  am_wait 120 kubectl -n argocd get application "orbit-$s"
  am_wait_app "orbit-$s" sync=Synced health=Healthy --timeout 180
done

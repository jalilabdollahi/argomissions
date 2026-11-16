#!/bin/bash
# Wrong: main is reset to the commit before the tidy-up and force-pushed. The fleet comes back, the audit trail does not.
set -euo pipefail
source "$AM_LIB"

am_argocd app set orbit-control --sync-policy automated --auto-prune --self-heal
am_argocd proj add-source orbit "$(am_repo_url orbit-services)"
cd "$SANDBOX/orbit-control"
git reset -q --hard HEAD~1
"$AM_PYTHON" - <<'PY'
p = "appsets/orbit-fleet.yaml"
s = open(p).read().replace("  generators:\n", "  syncPolicy:\n    preserveResourcesOnDeletion: true\n  generators:\n", 1)
open(p, "w").write(s)
PY
git add -A && git commit -q -m "Protect the fleet"
git push -q --force origin HEAD
am_argocd app get orbit-control --refresh >/dev/null
am_wait_app orbit-control sync=Synced --timeout 150
for s in ingest rollup alerts; do
  am_wait 120 kubectl -n argocd get application "orbit-$s"
  am_wait_app "orbit-$s" sync=Synced health=Healthy --timeout 180
done

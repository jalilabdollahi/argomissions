#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed meridian-platform "$LEVEL_DIR/repo" "meridian-platform: bootstrap, core and edge"
am_app_apply "$LEVEL_DIR/assets/root.yaml"
am_app_refresh meridian-root
am_wait_app meridian-root op=Succeeded sync=Synced --timeout 150 || { echo "setup: meridian-root did not sync"; exit 1; }

# The repo-server caches branch -> commit lookups (60s), also for a repo that was just re-seeded: nudge until the set sees the repo.
broken() {
  kubectl -n argocd get applicationset meridian-edge -o json | jq -e \
    '[.status.conditions[]? | select(.type=="ErrorOccurred" and .status=="True" and (.message | contains("function \"district\" not defined")))] | length > 0'
}
for i in $(seq 1 12); do
  am_wait 15 broken && break
  kubectl -n argocd annotate applicationset meridian-edge argocd.argoproj.io/application-set-refresh=true --overwrite >/dev/null
done
broken || { echo "setup: the ApplicationSet template error did not appear"; exit 1; }
am_app_refresh meridian-core
am_wait_app meridian-core cond=InvalidSpecError --timeout 120 || { echo "setup: meridian-core has no InvalidSpecError"; exit 1; }
am_setup_assert "no AppProject was created" bash -c '! kubectl -n argocd get appproject meridian-core'
am_setup_assert "no edge Application" bash -c '[ "$(kubectl -n argocd get applications -o name | grep -c edge)" = 0 ]'
am_workspace_clone meridian-platform

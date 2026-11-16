#!/bin/bash
# Wrong: the outage is reverted properly, the automation and the project are restored, but nothing protects the
# fleet against the next deletion.
set -euo pipefail
source "$AM_LIB"

am_argocd app set orbit-control --sync-policy automated --auto-prune --self-heal
am_argocd proj add-source orbit "$(am_repo_url orbit-services)"
cd "$SANDBOX/orbit-control"
git revert --no-edit HEAD
git push -q origin HEAD
am_argocd app get orbit-control --refresh >/dev/null
am_wait_app orbit-control sync=Synced --timeout 150
for s in ingest rollup alerts; do
  am_wait 120 kubectl -n argocd get application "orbit-$s"
  am_wait_app "orbit-$s" sync=Synced health=Healthy --timeout 180
done

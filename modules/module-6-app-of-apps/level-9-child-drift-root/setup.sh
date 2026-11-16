#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed courier-services "$LEVEL_DIR/repos/courier-services" "courier-services: api v2.4.0, web v1.9.0"
am_repo_branch courier-services hotfix-routing main
BRANCH=hotfix-routing am_repo_commit courier-services "$LEVEL_DIR/assets/hotfix" "api v2.4.1: route parcels to the right depot"
am_repo_seed courier-fleet "$LEVEL_DIR/repos/courier-fleet" "courier-fleet: api and web"
am_app_apply "$LEVEL_DIR/assets/root.yaml"
am_app_refresh courier-fleet
for a in courier-fleet courier-routing courier-tracking; do
  am_wait_app "$a" sync=Synced health=Healthy --timeout 150 || { echo "setup: $a is not Synced and Healthy"; exit 1; }
done

# The on-call's attempt, and the root undoing it.
am_argocd app set courier-routing --revision hotfix-routing >/dev/null
am_wait_app courier-routing sync=Synced health=Healthy --timeout 90 || true
reverted() { [ "$(am_app courier-routing '{.spec.source.targetRevision}')" = main ]; }
am_wait 120 reverted || { echo "setup: courier-fleet did not revert the manual change"; exit 1; }
am_wait_app courier-routing sync=Synced health=Healthy --timeout 120 || { echo "setup: courier-routing did not settle"; exit 1; }
body="$(am_http http://courier-routing.courier-routing courier-routing)" || { echo "setup: courier-routing does not answer"; exit 1; }
[ "$body" = "courier-routing v2.4.0" ] || { echo "setup: courier-routing answers '$body'"; exit 1; }
am_workspace_clone courier-fleet

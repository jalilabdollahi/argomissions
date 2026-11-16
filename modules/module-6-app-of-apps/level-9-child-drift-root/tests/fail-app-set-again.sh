#!/bin/bash
# Wrong: the same CLI change again. The root reverts it once more.
set -euo pipefail
source "$AM_LIB"

am_argocd app set courier-routing --revision hotfix-routing
reverted() { [ "$(am_app courier-routing '{.spec.source.targetRevision}')" = main ]; }
am_wait 120 reverted || true
am_wait_app courier-routing sync=Synced health=Healthy --timeout 150 || true

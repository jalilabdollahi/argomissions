#!/bin/bash
# Wrong: the child is pinned with the CLI. The root's self-heal puts main back.
set -euo pipefail
source "$AM_LIB"

am_argocd app set meterhub-prod --revision v1.2.0
am_argocd app sync meterhub-prod --timeout 120 || true
reverted() { [ "$(am_app meterhub-prod '{.spec.source.targetRevision}')" = main ]; }
am_wait 120 reverted || true
am_wait_app meterhub-prod sync=Synced health=Healthy --timeout 150 || true

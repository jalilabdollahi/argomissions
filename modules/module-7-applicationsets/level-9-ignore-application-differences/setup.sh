#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed feedhub "$LEVEL_DIR/repo" "feedhub v1.8"
am_repo_branch feedhub hotfix-1.8.1 >/dev/null 2>&1
BRANCH=hotfix-1.8.1 am_repo_commit feedhub "$LEVEL_DIR/assets/hotfix" "Fix feed ordering (hotfix 1.8.1)" >/dev/null 2>&1
cp "$LEVEL_DIR/assets/appset.yaml" "$SANDBOX/feedhub-appset.yaml"
kubectl apply -f "$LEVEL_DIR/assets/appset.yaml" >/dev/null

for e in dev stage prod; do
  am_wait_app "feedhub-$e" sync=Synced health=Healthy --timeout 150 \
    || { echo "setup: feedhub-$e did not become healthy"; exit 1; }
done

# The first attempt of the on-call engineer: it is reverted by the ApplicationSet.
kubectl -n argocd patch application feedhub-prod --type merge \
  -p '{"spec":{"source":{"targetRevision":"hotfix-1.8.1"}}}' >/dev/null
back_on_main() { [ "$(am_app feedhub-prod '{.spec.source.targetRevision}')" = main ]; }
am_wait 60 back_on_main || { echo "setup: the ApplicationSet did not revert the manual change"; exit 1; }

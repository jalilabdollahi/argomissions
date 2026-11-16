#!/bin/bash
# Correct too: move the non-service folder out of apps/ in Git, so the generator never sees it.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/studio-platform"
mkdir -p ci
git mv apps/shared ci/shared
am_player_push "$SANDBOX/studio-platform" "move shared defaults out of apps/"
kubectl -n argocd annotate applicationset studio argocd.argoproj.io/application-set-refresh=true --overwrite >/dev/null
am_wait 150 bash -c '! kubectl -n argocd get application studio-shared' || { echo "studio-shared still exists"; exit 1; }
am_wait 60 bash -c '! kubectl -n studio get configmap studio-defaults' || { echo "configmap still exists"; exit 1; }
head="$(am_repo_head studio-platform)"
for s in render thumbnails captions; do
  am_wait_app "studio-$s" sync=Synced health=Healthy rev="$head" --timeout 150
done

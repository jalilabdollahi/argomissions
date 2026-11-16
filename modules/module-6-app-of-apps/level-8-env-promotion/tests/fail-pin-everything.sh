#!/bin/bash
# Wrong (over-correction): staging is pinned to the release as well, it no longer follows main.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/meterhub-gitops"
for env in staging prod; do
  sed -i.bak 's/targetRevision: main/targetRevision: v1.2.0/' envs/$env/meterhub.yaml && rm -f envs/$env/meterhub.yaml.bak
done
am_player_push . "pin both environments to v1.2.0"
head="$(am_repo_head meterhub-gitops)"
for env in staging prod; do
  am_app_refresh "meterhub-env-$env"
  am_wait_app "meterhub-env-$env" sync=Synced oprev="$head" --timeout 150
  am_wait_app "meterhub-$env" sync=Synced health=Healthy --timeout 150
done

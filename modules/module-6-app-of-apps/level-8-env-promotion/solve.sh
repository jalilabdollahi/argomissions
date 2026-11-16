#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/meterhub-gitops"
sed -i.bak 's/targetRevision: main/targetRevision: v1.2.0/' envs/prod/meterhub.yaml && rm -f envs/prod/meterhub.yaml.bak
am_player_push . "prod: pin meterhub to the release tag v1.2.0"
head="$(am_repo_head meterhub-gitops)"
am_app_refresh meterhub-env-prod
am_wait_app meterhub-env-prod sync=Synced oprev="$head" --timeout 150
am_wait_app meterhub-prod sync=Synced health=Healthy --timeout 150

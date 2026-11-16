#!/bin/bash
# Wrong: the children are moved to the default project in Git, which sidesteps the team project.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/tracing-gitops"
sed -i.bak 's/project: tracing-team/project: default/' apps/*.yaml && rm apps/*.bak
am_player_push . "children: use project default"
head="$(am_repo_head tracing-gitops)"
am_app_refresh tracing-root
am_wait_app tracing-root rev="$head" sync=Synced --timeout 120
for c in trace-collector trace-query; do
  am_app_refresh "$c"
  am_wait_app "$c" sync=Synced health=Healthy --timeout 150
done

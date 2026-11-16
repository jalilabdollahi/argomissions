#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app get trace-collector || true
kubectl -n argocd get appproject
cd "$SANDBOX/tracing-gitops"
cp "$LEVEL_DIR/assets/project.yaml" apps/project.yaml
am_player_push . "add AppProject tracing-team (wave -1) to the root folder"
head="$(am_repo_head tracing-gitops)"
am_app_refresh tracing-root
am_wait_app tracing-root rev="$head" sync=Synced --timeout 120
for c in trace-collector trace-query; do
  am_app_refresh "$c"
  am_wait_app "$c" sync=Synced health=Healthy rev="$head" --timeout 150
done

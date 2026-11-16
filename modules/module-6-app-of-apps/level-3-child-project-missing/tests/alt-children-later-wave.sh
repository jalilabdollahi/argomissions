#!/bin/bash
# Correct too: the project keeps the default wave and the children are pushed to wave 1.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/tracing-gitops"
grep -v "sync-wave\|^  annotations:" "$LEVEL_DIR/assets/project.yaml" >apps/project.yaml
for f in apps/collector.yaml apps/tquery.yaml; do
  sed -i.bak 's/^  namespace: argocd/  namespace: argocd\n  annotations:\n    argocd.argoproj.io\/sync-wave: "1"/' "$f" && rm "$f.bak"
done
am_player_push . "AppProject tracing-team; children in wave 1"
head="$(am_repo_head tracing-gitops)"
am_app_refresh tracing-root
am_wait_app tracing-root rev="$head" sync=Synced --timeout 120
for c in trace-collector trace-query; do
  am_app_refresh "$c"
  am_wait_app "$c" sync=Synced health=Healthy rev="$head" --timeout 150
done

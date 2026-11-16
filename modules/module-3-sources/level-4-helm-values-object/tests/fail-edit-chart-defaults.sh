#!/bin/bash
# Wrong: put the production values into chart/values.yaml. It works, but the team decided that environment
# values live in the Application, and the chart defaults would now deploy production settings on every laptop.
set -euo pipefail
source "$AM_LIB"

am_workspace_clone search-suggest
cd "$SANDBOX/search-suggest"
cat > chart/values.yaml <<'Y'
replicaCount: 3
banner: "search-suggest prod 4.1"
Y
am_player_push . "Production values in the chart"
am_app_refresh search-suggest
am_argocd app sync search-suggest --timeout 120
am_wait_app search-suggest sync=Synced health=Healthy rev="$(am_repo_head search-suggest)" --timeout 120
kubectl -n search rollout status deploy/search-suggest --timeout=90s

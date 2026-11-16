#!/bin/bash
# Wrong: everything is fixed except the old incident parameter, so the service answers the hotfix banner.
set -euo pipefail
source "$AM_LIB"

am_argocd app set stockroom-db-v2 --values values/production.yaml
am_argocd app set stockroom-db-v2 --release-name stockroom-db
cd "$SANDBOX/stockroom-db"
cat >>chart/values/production.yaml <<'YAML'
persistence:
  claimName: stockroom-db-data
YAML
am_player_push . "production: keep using the existing data volume"
am_argocd app get stockroom-db-v2 --hard-refresh >/dev/null
am_wait_app stockroom-db-v2 sync=OutOfSync --timeout 90
am_argocd app sync stockroom-db-v2 --timeout 150
am_wait_app stockroom-db-v2 sync=Synced health=Healthy --timeout 150

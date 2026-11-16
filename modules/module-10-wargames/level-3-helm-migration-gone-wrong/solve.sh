#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# 1. values file: it is called production.yaml; 2. drop the stale incident parameter; 3. keep the old object names
am_argocd app set stockroom-db-v2 --values values/production.yaml
am_argocd app unset stockroom-db-v2 --parameter message
am_argocd app set stockroom-db-v2 --release-name stockroom-db
# 4. the chart's default claim name would create an empty volume: point it at the existing claim (in Git)
cd "$SANDBOX/stockroom-db"
cat >>chart/values/production.yaml <<'YAML'
persistence:
  claimName: stockroom-db-data
YAML
am_player_push . "production: keep using the existing data volume"
am_argocd app get stockroom-db-v2 --hard-refresh >/dev/null
am_wait_app stockroom-db-v2 sync=OutOfSync --timeout 90
am_argocd app diff stockroom-db-v2 || true
am_argocd app sync stockroom-db-v2 --timeout 150
am_wait_app stockroom-db-v2 sync=Synced health=Healthy --timeout 150

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed smtp-gateway "$LEVEL_DIR/repo" "smtp-gateway v1.4 with credentials"
kubectl create namespace smtp-gw >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh smtp-gateway
am_wait_app smtp-gateway sync=Synced health=Healthy --timeout 150 \
  || { echo "setup: smtp-gateway did not become healthy"; exit 1; }
leaked() { [ "$(kubectl -n smtp-gw get secret smtp-credentials -o jsonpath='{.data.password}' | base64 -d)" = "Tr0ub4dor-smtp-2291" ]; }
am_setup_assert "the live Secret holds the leaked password" leaked
am_workspace_clone smtp-gateway

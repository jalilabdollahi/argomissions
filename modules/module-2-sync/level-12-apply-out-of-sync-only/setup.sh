#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed region-configs "$LEVEL_DIR/repo" "release r41"
kubectl create namespace regions >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh region-configs
am_wait_app region-configs sync=OutOfSync --timeout 60 || { echo "setup: app did not appear"; exit 1; }
am_argocd app sync region-configs --timeout 120 >/dev/null
am_wait_app region-configs sync=Synced health=Healthy --timeout 120 || { echo "setup: r41 did not deploy"; exit 1; }

# the analytics controller has been counting visits since
kubectl -n regions patch configmap visit-counter --field-manager=analytics-controller \
  --type merge -p '{"data":{"count":"4821"}}' >/dev/null

# release r42 is waiting
am_repo_commit region-configs "$LEVEL_DIR/assets/r42" "release r42: spring banner, eu-west template"
am_app_refresh region-configs
am_wait_app region-configs sync=OutOfSync --timeout 90 || { echo "setup: r42 not detected"; exit 1; }
am_setup_assert "counter is 4821" bash -c '[ "$(kubectl -n regions get cm visit-counter -o jsonpath={.data.count})" = 4821 ]'

am_workspace_clone region-configs

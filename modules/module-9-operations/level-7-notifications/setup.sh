#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl apply -f "$LEVEL_DIR/assets/receiver.yaml" >/dev/null
kubectl -n ops-hooks rollout status deploy/chat-hook --timeout=90s >/dev/null
am_setup_assert "the receiver answers" bash -c "source '$AM_LIB'; am_http http://chat-hook.ops-hooks/ping ops-hooks 5"

am_repo_seed payout-worker "$LEVEL_DIR/repo" "payout-worker v3.0"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh payout-worker
am_wait_app payout-worker sync=OutOfSync --timeout 120 || { echo "setup: payout-worker never became OutOfSync"; exit 1; }
am_app_sync_now payout-worker
am_wait_app payout-worker op=Failed --timeout 120 || { echo "setup: the first sync did not fail"; exit 1; }
am_workspace_clone payout-worker

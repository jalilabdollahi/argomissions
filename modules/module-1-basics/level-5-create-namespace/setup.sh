#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed ledger "$LEVEL_DIR/repo" "ledger v1.0 manifests"
# Namespace `ledger` deliberately does NOT exist.
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh ledger
am_wait_app ledger sync=OutOfSync --timeout 120 || { echo "setup: ledger never became OutOfSync"; exit 1; }
am_app_sync_now ledger   # the first sync attempt that the story says already failed
am_wait_app ledger op=Failed --timeout 120 || { echo "setup: the sync did not fail"; exit 1; }
am_setup_assert "the namespace does not exist" bash -c '! kubectl get namespace ledger'
am_workspace_clone ledger

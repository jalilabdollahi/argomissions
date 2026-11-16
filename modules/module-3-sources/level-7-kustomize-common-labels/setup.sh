#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed ledger-api "$LEVEL_DIR/repo" "ledger-api v2.2 kustomize package"
kubectl create namespace ledger >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh ledger-api
am_wait_app ledger-api sync=OutOfSync --timeout 90 || { echo "setup: app did not appear"; exit 1; }
am_argocd app sync ledger-api --timeout 120 >/dev/null
am_wait_app ledger-api sync=Synced health=Healthy --timeout 120 || { echo "setup: v2.2 did not become healthy"; exit 1; }

# the colleague's change: org-wide labels via commonLabels, synced from the UI
am_repo_commit ledger-api "$LEVEL_DIR/assets/labels-commit-dir" "add team and cost-center labels to every object"
am_app_refresh ledger-api
am_wait_app ledger-api sync=OutOfSync --timeout 90 || { echo "setup: new commit not seen"; exit 1; }
am_app_sync_now ledger-api
am_wait_app ledger-api op=Failed opmsg="field is immutable" --timeout 90 || { echo "setup: sync did not fail"; exit 1; }
am_workspace_clone ledger-api

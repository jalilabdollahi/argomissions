#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed tariff-gitops "$LEVEL_DIR/repo" "tariff-gitops: tariff-api and tariff-legacy"
am_app_apply "$LEVEL_DIR/assets/root.yaml"
am_app_refresh tariff-root
for c in tariff-api tariff-legacy; do
  am_wait_app "$c" sync=Synced health=Healthy --timeout 150 || { echo "setup: $c did not become Healthy"; exit 1; }
done
am_wait_app tariff-root sync=Synced --timeout 60

# The retirement commit: tariff-legacy leaves apps/ and the root (prune enabled) deletes its Application.
DELETE="apps/legacy.yaml" am_repo_commit tariff-gitops "" "retire tariff-legacy: remove its Application"
am_app_refresh tariff-root
am_wait 120 bash -c '! kubectl -n argocd get application tariff-legacy' || { echo "setup: tariff-legacy Application still exists"; exit 1; }
am_wait_app tariff-root sync=Synced --timeout 60
am_setup_assert "the retired workload still runs" bash -c 'kubectl -n tariff-old get deploy tariff-legacy'
am_workspace_clone tariff-gitops

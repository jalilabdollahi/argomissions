#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed query-service "$LEVEL_DIR/repo" "query-service v1"
kubectl create namespace search >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/project.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh query-service
am_wait_app query-service sync=Synced health=Healthy --timeout 150 \
  || { echo "setup: query-service did not become healthy"; exit 1; }

# The strays: a forgotten Deployment and the hand-managed TLS Secret.
kubectl apply -f "$LEVEL_DIR/assets/strays.yaml" >/dev/null
am_setup_assert "the stray deployment exists" kubectl -n search get deploy legacy-indexer
am_setup_assert "project has no orphaned-resource monitoring" bash -c \
  '[ "$(kubectl -n argocd get appproject search-platform -o jsonpath="{.spec.orphanedResources}")" = "" ]'
sleep 5
[ -z "$(am_app_conditions query-service)" ] || { echo "setup: app unexpectedly has conditions"; exit 1; }

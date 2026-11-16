#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed settle-api "$LEVEL_DIR/repo" "settle-api v1"
kubectl create namespace settlements >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/project.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh settle-api
am_wait_app settle-api sync=Synced health=Healthy --timeout 150 \
  || { echo "setup: settle-api did not become healthy"; exit 1; }

# The pipeline's namespace, with the template placeholder instead of a credential.
kubectl apply -f "$LEVEL_DIR/assets/ci-secret.yaml" >/dev/null
am_setup_assert "project has no roles yet" bash -c \
  '[ "$(kubectl -n argocd get appproject settlements -o jsonpath="{.spec.roles}")" = "" ]'

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed lexicon-site "$LEVEL_DIR/repo" "lexicon-site v3.1 manifests"
kubectl create namespace lexicon >/dev/null

# The platform team's "memory saving" resource.exclusions, already in place when the app is onboarded.
kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$LEVEL_DIR/assets/exclusions.yaml" >/dev/null
sleep 10   # the controller reloads argocd-cm and rebuilds its cluster cache

am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh lexicon-site
am_wait_app lexicon-site sync=OutOfSync --timeout 90 || { echo "setup: app not loaded"; exit 1; }
am_app_sync_now lexicon-site
am_wait_app lexicon-site op=Succeeded --timeout 90 || { echo "setup: first sync did not finish"; exit 1; }
am_workspace_clone lexicon-site

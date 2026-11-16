#!/bin/bash
# Correct too: promote by editing the tag pinned in the prod overlay, in Git.
set -euo pipefail
source "$AM_LIB"

am_workspace_clone ticket-desk
cd "$SANDBOX/ticket-desk"
cp kustomize/overlays/staging/kustomization.yaml kustomize/overlays/prod/kustomization.yaml
am_player_push . "Promote build 2.0 to prod"
am_app_refresh ticket-desk
am_argocd app sync ticket-desk --timeout 120
am_wait_app ticket-desk sync=Synced health=Healthy rev="$(am_repo_head ticket-desk)" --timeout 120
kubectl -n desk rollout status deploy/ticket-desk --timeout=90s

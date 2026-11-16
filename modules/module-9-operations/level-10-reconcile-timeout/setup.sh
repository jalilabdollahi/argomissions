#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed lobby-board "$LEVEL_DIR/repo" "lobby-board v1.0"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh lobby-board
am_wait_app lobby-board sync=Synced health=Healthy op=Succeeded --timeout 150 || { echo "setup: lobby-board v1.0 did not deploy"; exit 1; }

# The "CPU saving" change: 24h, live in the controller (clock) and in the repo-server (branch cache).
kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"timeout.reconciliation":"24h"}}' >/dev/null
kubectl -n argocd rollout restart statefulset/argocd-application-controller deploy/argocd-repo-server >/dev/null
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=180s >/dev/null
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=180s >/dev/null
live_24h() {
  [ "$(kubectl -n argocd exec argocd-application-controller-0 -- printenv ARGOCD_RECONCILIATION_TIMEOUT)" = 24h ]
}
am_setup_assert "the controller runs with a 24h reconciliation timeout" am_wait 60 live_24h
am_wait_app lobby-board sync=Synced health=Healthy --timeout 120 || { echo "setup: lobby-board unhealthy after restart"; exit 1; }
sleep 15   # let the controller finish its start-up pass before the release lands

# The release nobody notices.
am_repo_commit lobby-board "$LEVEL_DIR/assets/v2" "lobby-board v1.1: new opening hours"
head="$(am_repo_head lobby-board)"
sleep 25
unnoticed() { [ "$(am_app_rev lobby-board)" != "$head" ] && [ "$(am_app_sync lobby-board)" = Synced ]; }
am_setup_assert "Argo CD has not noticed the new commit" unnoticed
am_workspace_clone lobby-board

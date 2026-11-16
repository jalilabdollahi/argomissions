#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# Last Friday's state: bf-cart v8.2 is live, healthy and auto-synced; bf-promo is a brand-new Application.
am_repo_seed bf-cart "$LEVEL_DIR/repos/bf-cart" "bf-cart v8.2 manifests"
am_repo_seed bf-promo "$LEVEL_DIR/repos/bf-promo" "bf-promo v4.0: sale banner"
kubectl create namespace bf-cart >/dev/null
kubectl create namespace bf-scaler >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/project.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/apps.yaml"
am_app_refresh bf-cart
am_app_refresh bf-promo
am_wait_app bf-cart sync=Synced health=Healthy --timeout 150 || { echo "setup: bf-cart did not become healthy"; exit 1; }

# Monday: the Black Friday freeze goes in, and the platform's autoscaler starts doing its job.
kubectl -n argocd patch appproject blackfriday --type merge --patch-file "$LEVEL_DIR/assets/freeze.yaml" >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/load-scaler.yaml" >/dev/null
kubectl -n bf-scaler rollout status deploy/load-scaler --timeout=90s >/dev/null
scaled() { [ "$(kubectl -n bf-cart get deploy bf-cart -o jsonpath='{.spec.replicas}')" = 6 ]; }
am_setup_assert "the autoscaler raised bf-cart to 6 replicas" am_wait 60 scaled

# Tuesday: the approved release lands in Git, behind the freeze.
am_repo_commit bf-cart "$LEVEL_DIR/assets/release-cart" "Release v9.0: black friday build"
am_app_refresh bf-cart
am_wait_app bf-cart sync=OutOfSync --timeout 90 || { echo "setup: bf-cart did not become OutOfSync"; exit 1; }
am_wait_app bf-promo cond="do not match any of the allowed destinations" --timeout 90 \
  || { echo "setup: bf-promo did not report the destination error"; exit 1; }
sleep 6   # an automated sync would have started by now
[ "$(am_app bf-cart '{.status.operationState.syncResult.revision}')" != "$(am_repo_head bf-cart)" ] \
  || { echo "setup: the freeze did not hold back the release"; exit 1; }
if am_argocd app sync bf-cart >"$AM_TMP/sync.out" 2>&1; then echo "setup: the freeze did not block a manual sync"; exit 1; fi
grep -q "blocked by sync window" "$AM_TMP/sync.out" || { echo "setup: unexpected sync error"; cat "$AM_TMP/sync.out"; exit 1; }

am_workspace_clone bf-cart
am_workspace_clone bf-promo

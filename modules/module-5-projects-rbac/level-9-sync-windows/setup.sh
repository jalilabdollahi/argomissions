#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed statement-api "$LEVEL_DIR/repo" "statement-api v1.4"
kubectl create namespace statements >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/project.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh statement-api
am_wait_app statement-api sync=Synced health=Healthy --timeout 150 \
  || { echo "setup: statement-api did not become healthy"; exit 1; }

# The month-end freeze, then the approved fix lands in Git.
kubectl -n argocd patch appproject billing-core --type merge --patch-file "$LEVEL_DIR/assets/freeze.yaml" >/dev/null
am_repo_commit statement-api "$LEVEL_DIR/assets/hotfix" "Fix rounding of statement totals (v1.4.1)"
am_app_refresh statement-api
am_wait_app statement-api sync=OutOfSync --timeout 90 || { echo "setup: app did not become OutOfSync"; exit 1; }
sleep 8   # an automated sync would have started by now
[ "$(am_app_op statement-api)" = Succeeded ] \
  && [ "$(am_app statement-api '{.status.operationState.syncResult.revision}')" != "$(am_repo_head statement-api)" ] \
  || { echo "setup: unexpected operation state"; exit 1; }
if am_argocd app sync statement-api >"$AM_TMP/sync.out" 2>&1; then echo "setup: the freeze did not block the sync"; exit 1; fi
grep -q "blocked by sync window" "$AM_TMP/sync.out" || { echo "setup: unexpected sync error"; cat "$AM_TMP/sync.out"; exit 1; }

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# Release 6 is live. The migrator's RBAC was bootstrapped by hand when the service was first installed.
# a CRD applied by hand in an earlier run is not cleaned by the engine (no tracking annotation, no cleanup label)
kubectl delete crd shiftpolicies.rostering.argomissions.io --ignore-not-found --wait=true >/dev/null
am_repo_seed shiftboard "$LEVEL_DIR/repo" "shiftboard v6"
kubectl create namespace shiftboard >/dev/null
kubectl -n shiftboard apply -f "$LEVEL_DIR/repo/deploy/rbac.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh shiftboard; am_app_refresh rota-crds
am_wait_app rota-crds sync=OutOfSync --timeout 120 || { echo "setup: rota-crds never became OutOfSync"; exit 1; }
am_app_sync_now rota-crds
am_wait_app rota-crds op=Succeeded sync=Synced --timeout 120 || { echo "setup: the CRD did not sync"; exit 1; }
am_wait_app shiftboard sync=OutOfSync --timeout 120 || { echo "setup: shiftboard never became OutOfSync"; exit 1; }
am_app_sync_now shiftboard
am_wait_app shiftboard op=Succeeded sync=Synced health=Healthy --timeout 150 || { echo "setup: release v6 did not sync"; exit 1; }
am_setup_assert "v6 is live and migrated" bash -c "[ \"\$(kubectl -n shiftboard get cm schema-version -o jsonpath='{.data.version}')\" = v6 ]"

# Release 7 lands. First attempt, 06:40: the migration Job of release 6 is still there and the new one differs.
am_repo_commit shiftboard "$LEVEL_DIR/assets/release" "release v7: weekend rota policies (migration 0007)"
head="$(am_repo_head shiftboard)"
am_app_refresh shiftboard; am_app_refresh rota-crds
am_wait_app shiftboard sync=OutOfSync rev="$head" --timeout 120 || { echo "setup: Application did not see release v7"; exit 1; }
am_app_sync_now shiftboard "$head"
am_wait_app shiftboard op=Failed opmsg="field is immutable" --timeout 120 || { echo "setup: the first v7 sync did not fail on the Job"; exit 1; }

# 06:55: on-call just syncs again (the failed hook was cleaned up by its HookFailed policy); it fails differently.
kubectl -n shiftboard delete job rota-migrate --ignore-not-found --wait=true >/dev/null
am_app_sync_now shiftboard "$head"
second() { [ "$(am_app_op shiftboard)" = Failed ] && ! am_app shiftboard '{.status.operationState.message}' | grep -q immutable; }
am_wait 120 second || { echo "setup: the second v7 sync did not fail differently"; exit 1; }
sleep 5
am_setup_assert "the CRD Application lags behind" bash -c '[ "$(kubectl -n argocd get application rota-crds -o jsonpath="{.status.sync.status}")" = OutOfSync ]'
am_setup_assert "release v6 still serving" bash -c "[ \"\$(source '$AM_LIB'; am_http http://shiftboard.shiftboard shiftboard)\" = 'shiftboard v6' ]"
am_workspace_clone shiftboard

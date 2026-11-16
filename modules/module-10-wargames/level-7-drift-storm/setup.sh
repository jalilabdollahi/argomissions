#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed stormwatch "$LEVEL_DIR/repo" "stormwatch: ingest v2.0, alerts v1.0"
c1="$(am_repo_head stormwatch)"
kubectl create namespace stormwatch >/dev/null
kubectl create namespace stormwatch-mesh >/dev/null
am_app_apply "$LEVEL_DIR/assets/root.yaml"
am_app_refresh stormwatch-root
am_wait_app stormwatch-root sync=OutOfSync --timeout 120 || { echo "setup: the root never saw the repo"; exit 1; }
am_app_sync_now stormwatch-root
for a in stormwatch-root sw-ingest sw-alerts; do
  am_wait_app "$a" sync=Synced health=Healthy --timeout 150 || { echo "setup: $a did not become healthy"; exit 1; }
done

# Storm night: the alerts rollout is pinned to the current commit by hand (the root is synced manually and never undoes it).
am_argocd app set sw-alerts --revision "$c1" >/dev/null
am_wait_app sw-alerts rev="$c1" sync=Synced --timeout 60 || true

# Release day: ingest v2.1 and alerts v1.1, which also brings its own copy of the thresholds ConfigMap.
am_repo_commit stormwatch "$LEVEL_DIR/assets/release" "release: ingest v2.1, alerts v1.1 with wind threshold"
c2="$(am_repo_head stormwatch)"
for a in stormwatch-root sw-ingest sw-alerts; do am_app_refresh "$a"; done
am_wait_app sw-ingest rev="$c2" sync=Synced health=Healthy --timeout 150 || { echo "setup: ingest did not reach v2.1"; exit 1; }
# the pinned alerts keep serving v1.0 ...
# ... the mesh team's controller starts stamping ingest ...
kubectl apply -f "$LEVEL_DIR/assets/mesh-stamper.yaml" >/dev/null
kubectl -n stormwatch-mesh rollout status deploy/mesh-stamper --timeout=90s >/dev/null
am_wait_app sw-ingest sync=OutOfSync --timeout 120 || { echo "setup: the mutation was not detected"; exit 1; }
# ... and somebody debugs ingest in place.
kubectl -n stormwatch patch deploy sw-ingest --type json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/args/0","value":"-text=sw-ingest v2.1-debug"}]' >/dev/null
kubectl -n stormwatch rollout status deploy/sw-ingest --timeout=90s >/dev/null
am_app_refresh stormwatch-root
sleep 8
am_setup_assert "root is OutOfSync (hand-edited child)" bash -c '[ "$(kubectl -n argocd get application stormwatch-root -o jsonpath="{.status.sync.status}")" = OutOfSync ]'
am_setup_assert "alerts pinned" bash -c "[ \"\$(kubectl -n argocd get application sw-alerts -o jsonpath='{.spec.source.targetRevision}')\" = $c1 ]"
am_setup_assert "ingest drifted" bash -c '[ "$(kubectl -n argocd get application sw-ingest -o jsonpath="{.status.sync.status}")" = OutOfSync ]'
am_workspace_clone stormwatch

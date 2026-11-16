#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# The cluster's repo-server needs the kv-render sidecar (the engine does not restore the repo-server
# Deployment). The sidecar waits harmlessly when its ConfigMap is absent. Always restart so the sidecar
# reads the plugin config that is in the ConfigMap right now.
kubectl apply -f "$LEVEL_DIR/assets/plugin-bad.yaml" >/dev/null
kubectl -n argocd patch deploy argocd-repo-server --type strategic --patch-file "$LEVEL_DIR/assets/repo-server-sidecar.json" >/dev/null
kubectl -n argocd rollout restart deploy/argocd-repo-server >/dev/null
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=180s >/dev/null

cmp_serving() {
  local pod
  pod="$(kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-repo-server -o json \
    | jq -r '[.items[] | select(.metadata.deletionTimestamp == null)][0].metadata.name')"
  kubectl -n argocd logs "$pod" -c kv-render-cmp 2>/dev/null | grep -q 'serving on'
}
am_setup_assert "the kv-render plugin sidecar is serving" am_wait 90 cmp_serving

am_repo_seed label-printer "$LEVEL_DIR/repo" "label-printer v2.1 described by app.conf"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh label-printer
am_wait_app label-printer sync=Synced health=Healthy --timeout 120 || { echo "setup: label-printer never settled"; exit 1; }
src_type() { [ "$(am_app label-printer '{.status.sourceType}')" = Directory ]; }
am_setup_assert "the Application is rendered as a plain directory" am_wait 30 src_type
am_setup_assert "nothing runs in labels-print" bash -c "! kubectl -n labels-print get deploy label-printer"
am_workspace_clone label-printer

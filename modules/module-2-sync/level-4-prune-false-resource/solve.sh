#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/media-store"
# Step 1: protect the claim and tell Argo CD to stop counting it as a difference. Sync it so the live object carries it.
cat >deploy/pvc.yaml <<'YAML'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: uploads
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
    argocd.argoproj.io/compare-options: IgnoreExtraneous
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 64Mi
YAML
am_player_push . "uploads: protect the claim before it leaves the repo"
am_app_refresh media-store
am_wait_app media-store sync=Synced rev="$(am_repo_head media-store)" --timeout 120
am_wait 30 bash -c "kubectl -n media get pvc uploads -o jsonpath='{.metadata.annotations}' | grep -q Prune=false"
# Step 2: now the manifest can go.
git rm -q deploy/pvc.yaml
am_player_push . "uploads: moves to the storage app"
am_app_refresh media-store
am_wait_app media-store sync=Synced health=Healthy rev="$(am_repo_head media-store)" --timeout 120

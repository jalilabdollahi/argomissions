#!/bin/bash
set -euo pipefail
source "$AM_LIB"

HOOK_SECRET=catalog-hook-Wq4x91
am_repo_seed catalog-api "$LEVEL_DIR/repo" "catalog-api v1.0 manifests"
kubectl create namespace catalog >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh catalog-api
am_wait_app catalog-api sync=Synced health=Healthy --timeout 150 \
  || { echo "setup: catalog-api did not become healthy"; exit 1; }

# Argo CD side: the hook's secret went under the key people expect (ignored), a stale Gogs-era value under the real one.
kubectl -n argocd patch secret argocd-secret --type merge \
  -p "{\"stringData\":{\"webhook.gitea.secret\":\"$HOOK_SECRET\",\"webhook.gogs.secret\":\"old-gogs-secret-3310\"}}" >/dev/null
sleep 3
# Gitea side: a real push hook to Argo CD with the hook secret
am_gitea POST /repos/platform/catalog-api/hooks "$(jq -nc --arg s "$HOOK_SECRET" \
  '{type:"gitea",active:true,events:["push"],config:{url:"http://argocd-server.argocd.svc.cluster.local/api/webhook",content_type:"json",secret:$s}}')" >/dev/null

# A push Gitea announces, and Argo CD refuses
mkdir -p "$AM_TMP/v11/deploy"
sed 's/catalog-api v1.0/catalog-api v1.1/' "$LEVEL_DIR/repo/deploy/deployment.yaml" >"$AM_TMP/v11/deploy/deployment.yaml"
since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
am_repo_commit catalog-api "$AM_TMP/v11" "catalog-api v1.1"
refused() { kubectl -n argocd logs deploy/argocd-server --since-time="$since" 2>/dev/null | grep -q 'HMAC verification failed'; }
am_wait 60 refused || { echo "setup: Argo CD did not refuse Gitea's delivery"; exit 1; }
am_workspace_clone catalog-api

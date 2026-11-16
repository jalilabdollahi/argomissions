#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# read-only machine user + an access token for it, as the platform team set it up weeks ago
am_gitea DELETE /admin/users/argo-reader >/dev/null 2>&1 || true
am_gitea POST /admin/users '{"username":"argo-reader","email":"argo-reader@platform.local","password":"reader-pass-8Jt3","must_change_password":false}' >/dev/null

PRIVATE=1 am_repo_seed mailroom "$LEVEL_DIR/repo" "mailroom v3.1"
am_gitea PUT /repos/platform/mailroom/collaborators/argo-reader '{"permission":"read"}' >/dev/null
kubectl create namespace mailroom >/dev/null

token="$(curl -fsS -X POST -u argo-reader:reader-pass-8Jt3 -H 'Content-Type: application/json' \
  -d '{"name":"argocd-2026-q3","scopes":["read:repository"]}' "$AM_GIT_HOST/api/v1/users/argo-reader/tokens" | jq -r .sha1)"
[ -n "$token" ] && [ "$token" != null ] || { echo "setup: could not create the Gitea token"; exit 1; }
kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: repo-mailroom
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: $(am_repo_url mailroom)
  username: argo-reader
  password: $token
YAML

# the app works with the live token
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh mailroom
am_wait_app mailroom sync=Synced health=Healthy --timeout 150 || { echo "setup: mailroom did not sync with the valid token"; exit 1; }

# security clean-up revokes the token, then the team pushes v3.2
curl -fsS -X DELETE -u argo-reader:reader-pass-8Jt3 "$AM_GIT_HOST/api/v1/users/argo-reader/tokens/argocd-2026-q3" >/dev/null
am_repo_commit mailroom "$LEVEL_DIR/repo-v2" "mailroom v3.2"
am_app_refresh mailroom

unauth() { am_app_conditions mailroom | grep -q 'authentication required'; }
am_wait 120 unauth || { echo "setup: Argo CD did not report the revoked token"; exit 1; }
am_setup_assert "app is stuck at the old revision" bash -c '[ "$(kubectl -n argocd get application mailroom -o jsonpath="{.status.sync.revision}")" != "" ]'

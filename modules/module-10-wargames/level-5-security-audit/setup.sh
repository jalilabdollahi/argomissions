#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# Gitea: the machine user Argo CD is supposed to use. Onboarding only gave it access to custody-api.
am_gitea DELETE /admin/users/argo-reader >/dev/null 2>&1 || true
am_gitea POST /admin/users '{"username":"argo-reader","email":"argo-reader@platform.local","password":"reader-pass-8Rt3","must_change_password":false}' >/dev/null
for r in custody-api custody-batch; do PRIVATE=1 am_repo_seed "$r" "$LEVEL_DIR/repos/$r" "$r manifests"; done
am_gitea PUT /repos/platform/custody-api/collaborators/argo-reader '{"permission":"read"}' >/dev/null

kubectl create namespace custody >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/project.yaml" >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/repo-custody-api.yaml" -f "$LEVEL_DIR/assets/repo-custody-batch.yaml" >/dev/null
am_app_apply "$LEVEL_DIR/assets/apps.yaml"
for a in custody-api custody-batch; do am_app_refresh "$a"; done
for a in custody-api custody-batch; do
  am_wait_app "$a" sync=Synced health=Healthy --timeout 150 || { echo "setup: $a did not become healthy"; exit 1; }
done

# Local accounts and the demo-era default policy.
kubectl -n argocd patch configmap argocd-cm --type merge \
  -p '{"data":{"accounts.kim":"login","accounts.sam":"login","accounts.deploy-bot":"apiKey, login"}}' >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/rbac-everyone-admin.yaml" >/dev/null
for who in kim sam deploy-bot; do
  am_wait 60 am_argocd account update-password --account "$who" --current-password "$AM_ARGOCD_PASSWORD" --new-password "$who-pw-5521" \
    || { echo "setup: cannot set the password of $who"; exit 1; }
done
as_user() { env -u ARGOCD_OPTS argocd "$@" --config "$AM_TMP/sam-cli" --plaintext; }
as_user login "$AM_ARGOCD_ADDR" --username sam --password sam-pw-5521 >/dev/null
am_wait 30 bash -c "[ \"\$(env -u ARGOCD_OPTS argocd account can-i delete applications 'custody/custody-api' --config '$AM_TMP/sam-cli' --plaintext 2>/dev/null)\" = yes ]" \
  || { echo "setup: sam is not an admin yet"; exit 1; }

grep -q 'Summer2024!db' "$LEVEL_DIR/repos/custody-api/deploy/db-secret.yaml" || { echo "setup: seed lost the leaked password"; exit 1; }
am_workspace_clone custody-api
am_workspace_clone custody-batch

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed claims-portal "$LEVEL_DIR/repo" "claims-portal v1"
kubectl create namespace underwriting >/dev/null
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh claims-portal
am_wait_app claims-portal sync=Synced health=Healthy --timeout 150 \
  || { echo "setup: claims-portal did not become healthy"; exit 1; }

# Two local accounts that may log in; the engine restores argocd-cm / argocd-rbac-cm / account secrets between levels.
kubectl -n argocd patch configmap argocd-cm --type merge \
  -p '{"data":{"accounts.alice":"login","accounts.bob":"login"}}' >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/rbac-everyone-admin.yaml" >/dev/null
sleep 3
am_argocd account update-password --account alice --current-password "$AM_ARGOCD_PASSWORD" --new-password alice-pw-4821 >/dev/null
am_argocd account update-password --account bob --current-password "$AM_ARGOCD_PASSWORD" --new-password bob-pw-4821 >/dev/null

as_user() { env -u ARGOCD_OPTS argocd "$@" --config "$AM_TMP/bob-cli" --plaintext; }
as_user login "$AM_ARGOCD_ADDR" --username bob --password bob-pw-4821 >/dev/null
am_wait 20 bash -c "[ \"\$(env -u ARGOCD_OPTS argocd account can-i delete applications '*/*' --config '$AM_TMP/bob-cli' --plaintext 2>/dev/null)\" = yes ]" \
  || { echo "setup: bob is not an admin yet"; exit 1; }

#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl apply -f "$LEVEL_DIR/assets/crd.yaml" >/dev/null
kubectl wait --for=condition=Established crd/backups.vaultline.argomissions.io --timeout=30s >/dev/null
kubectl create namespace vaultline >/dev/null
am_repo_seed vaultline-backups "$LEVEL_DIR/repo" "vaultline backup schedules"
am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh vaultline
am_wait_app vaultline sync=Synced --timeout 150 || { echo "setup: first sync did not settle"; exit 1; }

# The vaultline operator reports what happened (it owns .status).
set_phase() {
  kubectl -n vaultline patch backups.vaultline.argomissions.io "$1" --subresource=status --type merge \
    -p "{\"status\":{\"phase\":\"$2\",\"message\":\"$3\"}}" >/dev/null
}
set_phase nightly-ledger Failed "upload to s3://vaultline-prod/ledger failed: AccessDenied"
set_phase weekly-archive Done "archived 41 GiB in 12m"
set_phase hourly-journal Running "streaming segment 7 of 12"
am_app_refresh vaultline normal

no_health() { [ "$(am_argocd app get vaultline -o json | jq '[.status.resources[] | select(.health != null)] | length')" = 0 ]; }
app_healthy() { [ "$(am_app_health vaultline)" = Healthy ]; }
am_setup_assert "Backups are reported without any health" no_health
am_setup_assert "application Synced and Healthy" app_healthy
am_workspace_clone vaultline-backups

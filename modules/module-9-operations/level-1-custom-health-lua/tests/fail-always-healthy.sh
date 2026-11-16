#!/bin/bash
# Wrong: a health check that only ever says Healthy (the dashboard stays green, the failure stays hidden).
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"resource.customizations.health.vaultline.argomissions.io_Backup":"hs = {}\nhs.status = \"Healthy\"\nreturn hs\n"}}'
am_app_refresh vaultline normal
sleep 5

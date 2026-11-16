#!/bin/bash
# Correct too: ignore everything the cost-stamper field manager writes.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application profile-svc --type merge -p '{"spec":{
  "ignoreDifferences":[{"group":"apps","kind":"Deployment","managedFieldsManagers":["cost-stamper"]}]}}'
am_wait_app profile-svc sync=Synced health=Healthy --timeout 120

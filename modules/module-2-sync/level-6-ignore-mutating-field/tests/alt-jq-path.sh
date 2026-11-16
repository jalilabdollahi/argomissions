#!/bin/bash
# Correct too: a jq path expression instead of a JSON pointer.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application profile-svc --type merge -p '{"spec":{
  "ignoreDifferences":[{"group":"apps","kind":"Deployment","jqPathExpressions":[".metadata.labels[\"cost-center\"]"]}]}}'
am_wait_app profile-svc sync=Synced health=Healthy --timeout 120

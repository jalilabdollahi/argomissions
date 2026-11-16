#!/bin/bash
# Correct too: ignoreDifferences for exactly the defaulted field.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application ops-statusboard --type merge -p \
  '{"spec":{"ignoreDifferences":[{"group":"argomissions.io","kind":"StatusBoard","jqPathExpressions":[".spec.panels[].refresh"]}]}}'
am_argocd app sync ops-statusboard --timeout 120
am_wait_app ops-statusboard sync=Synced health=Healthy --timeout 120

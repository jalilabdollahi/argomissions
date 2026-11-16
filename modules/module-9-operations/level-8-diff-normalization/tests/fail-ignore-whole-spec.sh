#!/bin/bash
# Wrong: silencing the whole spec makes the app Synced but also hides every real change.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application ops-statusboard --type merge -p \
  '{"spec":{"ignoreDifferences":[{"group":"argomissions.io","kind":"StatusBoard","jsonPointers":["/spec"]}]}}'
am_argocd app sync ops-statusboard --timeout 120
am_wait_app ops-statusboard sync=Synced health=Healthy --timeout 120

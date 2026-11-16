#!/bin/bash
# Wrong: the same ignoreDifferences copied into every Application (works today, not for the next service).
set -euo pipefail
source "$AM_LIB"

for s in ingest rollup gateway; do
  am_argocd app patch "tallyline-$s" --type merge --patch '{"spec":{"ignoreDifferences":[{"group":"apps","kind":"Deployment","jsonPointers":["/metadata/labels/complyd.argomissions.io~1scan"]}]}}'
  am_wait_app "tallyline-$s" sync=Synced health=Healthy --timeout 120
done

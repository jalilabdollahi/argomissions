#!/bin/bash
# Also correct: the production manifests are top-level in deploy/, so recursion is not needed at all.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application collector --type json -p '[{"op":"remove","path":"/spec/source/directory"}]'
am_wait_app collector sync=Synced health=Healthy --timeout 120
am_wait 90 bash -c '[ -z "$(kubectl -n telemetry get pods -o name | grep fixture)" ]'

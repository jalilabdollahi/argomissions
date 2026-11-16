#!/bin/bash
# Also correct: an include glob that names only the production manifests.
set -euo pipefail
source "$AM_LIB"

am_argocd app set collector --directory-include 'collector*.yaml'
am_wait_app collector sync=Synced health=Healthy --timeout 120
am_wait 90 bash -c '[ -z "$(kubectl -n telemetry get pods -o name | grep fixture)" ]'

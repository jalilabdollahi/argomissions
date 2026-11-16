#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_argocd app set collector --directory-exclude 'tests/*'
am_wait_app collector sync=Synced health=Healthy --timeout 120
am_wait 90 bash -c '[ -z "$(kubectl -n telemetry get pods -o name | grep fixture)" ]'

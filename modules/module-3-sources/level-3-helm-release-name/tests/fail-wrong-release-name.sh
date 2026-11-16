#!/bin/bash
# Wrong: a release name that already contains the suffix gives tracker-api-api.
set -euo pipefail
source "$AM_LIB"

am_argocd app set fleet-tracker --release-name tracker-api
sleep 3
am_wait_app fleet-tracker sync=Synced health=Healthy --timeout 150

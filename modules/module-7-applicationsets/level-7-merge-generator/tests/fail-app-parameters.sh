#!/bin/bash
# Wrong: the override set on the generated Application. It is not what the ApplicationSet generates and
# the ApplicationSet takes it back.
set -euo pipefail
source "$AM_LIB"

am_argocd app set parcel-api-prod -p replicas=3 -p "banner=parcel-api prod priority-lane"
am_argocd app sync parcel-api-prod --timeout 120 || true
sleep 15

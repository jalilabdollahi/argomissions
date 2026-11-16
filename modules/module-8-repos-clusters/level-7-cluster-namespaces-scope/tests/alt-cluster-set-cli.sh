#!/bin/bash
# Correct too: widen the scope with the CLI instead of editing the Secret.
set -euo pipefail
source "$AM_LIB"

am_argocd cluster set regional --namespace parcel-eu --namespace parcel-us >/dev/null
sleep 3
am_app_refresh parcel-hub-us normal
am_wait_app parcel-hub-us sync=Synced health=Healthy --timeout 150

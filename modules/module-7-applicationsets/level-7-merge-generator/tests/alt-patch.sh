#!/bin/bash
# Correct too: the override element re-keyed with a JSON patch on the live ApplicationSet.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset parcel-api --type json -p '[
  {"op":"remove","path":"/spec/generators/0/merge/generators/1/list/elements/0/environment"},
  {"op":"add","path":"/spec/generators/0/merge/generators/1/list/elements/0/env","value":"prod"}]'
ready3() { [ "$(am_ready_replicas parcel-api parcel-prod)" = 3 ]; }
am_wait 150 ready3
am_wait_app parcel-api-prod sync=Synced health=Healthy --timeout 150

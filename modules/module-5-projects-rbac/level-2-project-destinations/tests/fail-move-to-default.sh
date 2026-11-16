#!/bin/bash
# Wrong: move the app to `default`, which allows every destination.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application rx-dispatch --type merge -p '{"spec":{"project":"default"}}'
am_app_refresh rx-dispatch
am_wait_app rx-dispatch sync=Synced health=Healthy --timeout 150

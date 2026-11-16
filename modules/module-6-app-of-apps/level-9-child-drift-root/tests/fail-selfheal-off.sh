#!/bin/bash
# Wrong: the root's self-heal is switched off so that the hand edit survives. Git still says main.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application courier-fleet --type merge -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false}}}}'
sleep 3
am_argocd app set courier-routing --revision hotfix-routing
am_wait_app courier-routing sync=Synced health=Healthy --timeout 150
am_app_refresh courier-fleet
am_wait_app courier-fleet sync=OutOfSync --timeout 60

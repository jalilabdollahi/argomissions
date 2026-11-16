#!/bin/bash
# Correct too: the policy patched straight onto the Application resource.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application metrics-gw --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":false}}}}'
am_wait_app metrics-gw sync=Synced health=Healthy --timeout 120

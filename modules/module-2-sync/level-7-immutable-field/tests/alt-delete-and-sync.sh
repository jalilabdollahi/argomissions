#!/bin/bash
# Correct too: delete the old Deployment by hand, then sync so Argo CD creates the new one.
set -euo pipefail
source "$AM_LIB"

kubectl -n helpdesk delete deploy ticket-desk --wait=true
am_argocd app sync ticket-desk --timeout 120
am_wait_app ticket-desk sync=Synced health=Healthy --timeout 120

#!/bin/bash
# Wrong: delete the Deployment with kubectl and never sync. Nothing runs, Argo CD still reports the failure.
set -euo pipefail
source "$AM_LIB"

kubectl -n helpdesk delete deploy ticket-desk --wait=true

#!/bin/bash
# Wrong: sync release v2 as it is. The Job and the Deployment are applied together, the pods start
# before the migration has finished.
set -euo pipefail
source "$AM_LIB"

am_argocd app sync payroll-api --timeout 150
am_wait_app payroll-api sync=Synced health=Healthy --timeout 120

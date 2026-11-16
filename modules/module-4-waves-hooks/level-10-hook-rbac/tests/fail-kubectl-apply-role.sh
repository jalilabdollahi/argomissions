#!/bin/bash
# Wrong: apply the new Role by hand and re-sync. It works once, but Git still orders Role after the Job.
set -euo pipefail
source "$AM_LIB"

kubectl -n payroll apply -f "$SANDBOX/payroll-engine/deploy/rbac.yaml"
am_argocd app sync payroll-engine --timeout 180
am_argocd app wait payroll-engine --health --timeout 120

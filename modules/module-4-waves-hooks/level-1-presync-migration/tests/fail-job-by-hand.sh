#!/bin/bash
# Wrong: run the migration by hand first and sync afterwards. It works once, but Git still does not say
# that the migration comes first.
set -euo pipefail
source "$AM_LIB"

kubectl apply -n payroll -f "$SANDBOX/payroll-api/deploy/migrate-job.yaml"
kubectl -n payroll wait --for=condition=complete job/payroll-schema-migrate --timeout=90s
am_argocd app sync payroll-api --timeout 150
am_wait_app payroll-api sync=Synced health=Healthy --timeout 120

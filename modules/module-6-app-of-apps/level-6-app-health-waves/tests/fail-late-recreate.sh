#!/bin/bash
# Wrong: nothing is configured; beacon-api is merely deleted and re-created long after the database is up.
# The timestamps look right once, but Argo CD still ignores Application health.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application beacon-api --type json -p '[{"op":"remove","path":"/metadata/finalizers"}]' >/dev/null
kubectl -n argocd delete application beacon-api --wait=true >/dev/null
kubectl delete namespace beacon-edge --wait=true >/dev/null
am_app_refresh beacon-root
am_wait_app beacon-root sync=OutOfSync --timeout 60
am_argocd app sync beacon-root --timeout 180
am_wait_app beacon-api sync=Synced health=Healthy --timeout 180

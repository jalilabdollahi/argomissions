#!/bin/bash
# Wrong: a correctly labelled copy of the Secret in the app's namespace; Argo CD only reads its own namespace.
set -euo pipefail
source "$AM_LIB"

kubectl -n parcels create secret generic repo-parcel-tracker --from-literal=type=git \
  --from-literal=url="$(am_repo_url parcel-tracker)" --from-literal=username=argo-reader --from-literal=password=reader-pass-4Kd9
kubectl -n parcels label secret repo-parcel-tracker argocd.argoproj.io/secret-type=repository
am_argocd app get parcel-tracker --hard-refresh >/dev/null 2>&1 || true
sleep 5

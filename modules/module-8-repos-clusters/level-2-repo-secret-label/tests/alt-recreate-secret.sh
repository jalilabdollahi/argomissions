#!/bin/bash
# Correct too: delete the mislabelled Secret and create a proper one.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd delete secret repo-parcel-tracker
kubectl -n argocd create secret generic repo-parcel-tracker-fixed --from-literal=type=git \
  --from-literal=url="$(am_repo_url parcel-tracker)" --from-literal=username=argo-reader --from-literal=password=reader-pass-4Kd9
kubectl -n argocd label secret repo-parcel-tracker-fixed argocd.argoproj.io/secret-type=repository
am_argocd app get parcel-tracker --hard-refresh >/dev/null
am_wait_app parcel-tracker sync=Synced health=Healthy --timeout 150

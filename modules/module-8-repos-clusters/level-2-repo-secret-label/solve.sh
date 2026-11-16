#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd label secret repo-parcel-tracker argocd.argoproj.io/secret-type=repository --overwrite
am_argocd app get parcel-tracker --hard-refresh >/dev/null
am_wait_app parcel-tracker sync=Synced health=Healthy --timeout 150

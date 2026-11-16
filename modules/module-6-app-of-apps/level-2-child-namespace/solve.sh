#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl get applications.argoproj.io -A
am_argocd app get billing-root
am_argocd app set billing-root --dest-namespace argocd
# the root is OutOfSync (children to create in argocd, old copies in billing-system to prune); Argo CD does not
# auto-sync a revision it already synced, so sync with prune
am_wait_app billing-root sync=OutOfSync --timeout 60
am_argocd app sync billing-root --prune --timeout 120
am_wait_app billing-root sync=Synced --timeout 120
am_wait_app invoice-api sync=Synced health=Healthy --timeout 150
am_wait_app dunning-worker sync=Synced health=Healthy --timeout 150

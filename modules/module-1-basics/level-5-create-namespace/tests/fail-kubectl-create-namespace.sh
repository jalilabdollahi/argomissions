#!/bin/bash
# Wrong: create the namespace by hand and sync. It deploys today, but the Application still cannot
# bootstrap itself on a fresh cluster.
set -euo pipefail
source "$AM_LIB"

kubectl create namespace ledger
am_argocd app sync ledger --timeout 120
am_wait_app ledger sync=Synced health=Healthy --timeout 120

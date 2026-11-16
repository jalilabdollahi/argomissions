#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd label secret cluster-staging env=staging
am_wait_app quota-staging sync=Synced health=Healthy --timeout 150

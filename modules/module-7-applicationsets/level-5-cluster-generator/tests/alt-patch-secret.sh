#!/bin/bash
# Correct too: the label added with a merge patch on the cluster secret.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch secret cluster-staging --type merge -p '{"metadata":{"labels":{"env":"staging"}}}'
am_wait_app quota-staging sync=Synced health=Healthy --timeout 150

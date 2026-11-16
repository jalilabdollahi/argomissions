#!/bin/bash
# Wrong: the cluster is labelled with a key the selector does not use.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd label secret cluster-staging environment=staging
sleep 25

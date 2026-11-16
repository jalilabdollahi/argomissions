#!/bin/bash
# Correct too: the same values as a YAML string in helm.values instead of valuesObject.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application search-suggest --type merge -p \
  '{"spec":{"source":{"helm":{"valuesObject":null,"values":"replicaCount: 3\nbanner: \"search-suggest prod 4.1\"\n"}}}}'
am_app_refresh search-suggest
am_argocd app sync search-suggest --timeout 120
am_wait_app search-suggest sync=Synced health=Healthy --timeout 120
kubectl -n search rollout status deploy/search-suggest --timeout=90s

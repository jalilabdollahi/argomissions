#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# the chart source asks for $values, so name the values source `values`
kubectl -n argocd patch application pricing --type json \
  -p '[{"op":"replace","path":"/spec/sources/1/ref","value":"values"}]'
am_argocd app get pricing --refresh >/dev/null
am_argocd app sync pricing --timeout 120
am_argocd app wait pricing --health --timeout 120

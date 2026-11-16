#!/bin/bash
# Wrong: the reference is repaired but nobody syncs; nothing is deployed.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application pricing --type json \
  -p '[{"op":"replace","path":"/spec/sources/1/ref","value":"values"}]'
am_argocd app get pricing --refresh >/dev/null
am_wait_app pricing sync=OutOfSync --timeout 60

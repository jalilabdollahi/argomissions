#!/bin/bash
# Also correct: keep ref `env` and change the value file reference to $env.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application pricing --type json \
  -p '[{"op":"replace","path":"/spec/sources/0/helm/valueFiles/0","value":"$env/prod/values.yaml"}]'
am_argocd app get pricing --refresh >/dev/null
am_argocd app sync pricing --timeout 120
am_wait_app pricing sync=Synced health=Healthy --timeout 120

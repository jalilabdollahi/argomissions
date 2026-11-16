#!/bin/bash
# Wrong: the reference is repaired, but pointed at the staging values file. It syncs and runs the wrong text.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application pricing --type json -p '[
 {"op":"replace","path":"/spec/sources/1/ref","value":"values"},
 {"op":"replace","path":"/spec/sources/0/helm/valueFiles/0","value":"$values/staging/values.yaml"}]'
am_argocd app get pricing --refresh >/dev/null
am_argocd app sync pricing --timeout 120
am_wait_app pricing sync=Synced health=Healthy --timeout 120

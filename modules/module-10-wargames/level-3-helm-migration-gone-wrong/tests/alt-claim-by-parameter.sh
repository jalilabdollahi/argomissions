#!/bin/bash
# Correct too: the existing claim is passed as a Helm parameter on the Application instead of through the values file,
# the values file is fixed by pointing at the file with its real name.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application stockroom-db-v2 --type merge -p '{"spec":{"source":{"helm":{
  "releaseName":"stockroom-db","valueFiles":["values/production.yaml"],
  "parameters":[{"name":"persistence.claimName","value":"stockroom-db-data"}]}}}}'
am_argocd app get stockroom-db-v2 --hard-refresh >/dev/null
am_wait_app stockroom-db-v2 sync=OutOfSync --timeout 90
am_argocd app sync stockroom-db-v2 --timeout 150
am_wait_app stockroom-db-v2 sync=Synced health=Healthy --timeout 150

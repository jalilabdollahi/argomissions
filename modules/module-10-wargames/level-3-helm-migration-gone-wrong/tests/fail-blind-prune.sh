#!/bin/bash
# Wrong: the values file and parameter are fixed, the release name is left alone, and the "leftovers" of the old
# names are cleaned up with a pruning sync. The volume with the data is deleted.
set -euo pipefail
source "$AM_LIB"

am_argocd app set stockroom-db-v2 --values values/production.yaml
am_argocd app unset stockroom-db-v2 --parameter message
am_argocd app get stockroom-db-v2 --hard-refresh >/dev/null
am_wait_app stockroom-db-v2 sync=OutOfSync --timeout 90
am_argocd app sync stockroom-db-v2 --prune --timeout 150
am_wait 90 bash -c '! kubectl -n stockroom get pvc stockroom-db-data >/dev/null 2>&1'
am_wait_app stockroom-db-v2 sync=Synced health=Healthy --timeout 150

#!/bin/bash
# Wrong: values file, parameter and release name are fixed, but the chart's default claim is used: the database
# starts on a new, empty volume. Everything is green, the data is "gone".
set -euo pipefail
source "$AM_LIB"

am_argocd app set stockroom-db-v2 --values values/production.yaml
am_argocd app unset stockroom-db-v2 --parameter message
am_argocd app set stockroom-db-v2 --release-name stockroom-db
am_argocd app get stockroom-db-v2 --hard-refresh >/dev/null
am_wait_app stockroom-db-v2 sync=OutOfSync --timeout 90
am_argocd app sync stockroom-db-v2 --timeout 150 || true   # exits non-zero: the old claim 'requires pruning'
kubectl -n stockroom rollout status deploy/stockroom-db --timeout=120s

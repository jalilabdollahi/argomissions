#!/bin/bash
# Wrong (partial): the exclusion is lifted, but nobody syncs: the ConfigMap is still missing in the cluster.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$LEVEL_DIR/assets/exclusions-fixed.yaml"
sleep 5
am_app_refresh lexicon-site normal
am_wait_app lexicon-site sync=OutOfSync --timeout 60

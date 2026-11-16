#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$LEVEL_DIR/assets/exclusions-fixed.yaml"
sleep 5
am_app_refresh lexicon-site normal
am_wait_app lexicon-site sync=OutOfSync --timeout 60
am_argocd app sync lexicon-site --timeout 120
am_argocd app wait lexicon-site --health --timeout 120

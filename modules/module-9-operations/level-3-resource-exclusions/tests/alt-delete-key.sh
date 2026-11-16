#!/bin/bash
# Correct too: the custom list is removed altogether (Argo CD's built-in default exclusions apply), then a sync.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-cm --type json -p '[{"op":"remove","path":"/data/resource.exclusions"}]'
sleep 5
am_app_refresh lexicon-site normal
am_wait_app lexicon-site sync=OutOfSync --timeout 60
am_argocd app sync lexicon-site --timeout 120
am_argocd app wait lexicon-site --health --timeout 120

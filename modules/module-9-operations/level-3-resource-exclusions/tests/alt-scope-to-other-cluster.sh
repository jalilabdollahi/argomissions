#!/bin/bash
# Correct too: the ConfigMap rule is kept, but only for another (edge) cluster, not the in-cluster destination.
set -euo pipefail
source "$AM_LIB"

cat >"$AM_TMP/cm.yaml" <<'YAML'
data:
  resource.exclusions: |
    - apiGroups: ["*"]
      kinds: ["ConfigMap"]
      clusters: ["https://edge-01.example.com"]
    - apiGroups: ["discovery.k8s.io"]
      kinds: ["EndpointSlice"]
      clusters: ["*"]
YAML
kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$AM_TMP/cm.yaml"
sleep 5
am_app_refresh lexicon-site normal
am_wait_app lexicon-site sync=OutOfSync --timeout 60
am_argocd app sync lexicon-site --timeout 120
am_argocd app wait lexicon-site --health --timeout 120

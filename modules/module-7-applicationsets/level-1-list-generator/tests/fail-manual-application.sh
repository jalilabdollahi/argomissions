#!/bin/bash
# Wrong: the missing Application written by hand. It runs, but the ApplicationSet does not own it.
set -euo pipefail
source "$AM_LIB"

cat >"$AM_TMP/app.yaml" <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: geo-edge-eu-west
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $(am_repo_url geo-edge)
    targetRevision: main
    path: chart
    helm:
      parameters:
      - name: region
        value: eu-west
  destination:
    server: https://kubernetes.default.svc
    namespace: geo-eu-west
  syncPolicy:
    automated: {}
    syncOptions: [CreateNamespace=true]
YAML
kubectl apply -f "$AM_TMP/app.yaml"
am_wait_app geo-edge-eu-west sync=Synced health=Healthy --timeout 150

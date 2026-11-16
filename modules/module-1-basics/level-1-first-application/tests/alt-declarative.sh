#!/bin/bash
# Correct too: the Application written as YAML and applied with kubectl, synced from the CLI.
set -euo pipefail
source "$AM_LIB"

cat >"$AM_TMP/app.yaml" <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: status-page
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $(am_repo_url status-page)
    targetRevision: HEAD
    path: deploy/
  destination:
    name: in-cluster
    namespace: status
YAML
kubectl apply -f "$AM_TMP/app.yaml"
am_wait_app status-page sync=OutOfSync --timeout 60
am_argocd app sync status-page --timeout 120
am_wait_app status-page sync=Synced health=Healthy --timeout 120

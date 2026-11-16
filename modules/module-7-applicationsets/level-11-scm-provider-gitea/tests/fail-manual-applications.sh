#!/bin/bash
# Wrong: the three Applications written by hand; the ApplicationSet still cannot read the organization.
set -euo pipefail
source "$AM_LIB"

for r in pinger quill ember; do
kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mesh-$r
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $(am_repo_url mesh-$r)
    targetRevision: main
    path: deploy
  destination:
    server: https://kubernetes.default.svc
    namespace: mesh-$r
  syncPolicy:
    automated: {}
    syncOptions: [CreateNamespace=true]
YAML
done
for r in pinger quill ember; do am_wait_app "mesh-$r" sync=Synced health=Healthy --timeout 180; done

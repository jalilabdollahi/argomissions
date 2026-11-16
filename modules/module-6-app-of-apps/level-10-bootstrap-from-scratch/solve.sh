#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cat >"$SANDBOX/lighthouse-bootstrap.yaml" <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: lighthouse-bootstrap
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $(am_repo_url lighthouse-gitops)
    targetRevision: main
    path: platform
    directory:
      recurse: true
      exclude: 'apps/_archive/*'
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML
kubectl apply -f "$SANDBOX/lighthouse-bootstrap.yaml"
am_wait_app lighthouse-bootstrap sync=Synced health=Healthy op=Succeeded --timeout 240
for a in lighthouse-cache lighthouse-gateway lighthouse-catalog; do
  am_wait_app "$a" sync=Synced health=Healthy --timeout 240
done

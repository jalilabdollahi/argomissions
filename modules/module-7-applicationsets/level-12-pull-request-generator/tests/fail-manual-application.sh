#!/bin/bash
# Wrong: the preview Application written by hand; it is not owned by the ApplicationSet.
set -euo pipefail
source "$AM_LIB"

n="$(am_gitea GET "/repos/platform/pulse-web/pulls?state=open" | jq -r '[.[] | select(.head.ref=="checkout-redesign")][0].number')"
kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: pulse-pr-$n
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $(am_repo_url pulse-web)
    targetRevision: checkout-redesign
    path: deploy
  destination:
    server: https://kubernetes.default.svc
    namespace: pulse-pr-$n
  syncPolicy:
    automated: {prune: true}
    syncOptions: [CreateNamespace=true]
YAML
am_wait_app "pulse-pr-$n" sync=Synced health=Healthy --timeout 150

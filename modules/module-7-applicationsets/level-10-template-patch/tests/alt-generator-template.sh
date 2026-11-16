#!/bin/bash
# Correct too: no templatePatch; prod comes from its own list generator with a generator-level template that adds the policy.
set -euo pipefail
source "$AM_LIB"

kubectl apply -f - <<YAML
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: lumen-gateway
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
  - list:
      elements:
      - env: dev
      - env: stage
  - list:
      elements:
      - env: prod
      template:
        metadata: {name: 'lumen-{{.env}}'}
        spec:
          project: default
          destination: {}
          source: {repoURL: "", path: ""}
          syncPolicy:
            automated: {prune: true}
  template:
    metadata:
      name: 'lumen-{{.env}}'
    spec:
      project: default
      source:
        repoURL: http://gitea.gitea.svc.cluster.local:3000/platform/lumen-gateway.git
        targetRevision: main
        path: deploy
      destination:
        server: https://kubernetes.default.svc
        namespace: 'lumen-{{.env}}'
      syncPolicy:
        syncOptions:
        - CreateNamespace=true
YAML
am_wait_app lumen-prod sync=Synced health=Healthy --timeout 150

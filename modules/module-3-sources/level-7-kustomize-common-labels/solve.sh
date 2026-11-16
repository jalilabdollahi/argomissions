#!/bin/bash
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/ledger-api"
cat > deploy/kustomization.yaml <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
labels:
- pairs:
    team: ledger
    cost-center: cc-4711
  includeSelectors: false
  includeTemplates: true
YAML
am_player_push "$SANDBOX/ledger-api" "use labels with includeSelectors: false"
am_argocd app get ledger-api --refresh >/dev/null
am_argocd app sync ledger-api --timeout 120
am_argocd app wait ledger-api --health --timeout 120

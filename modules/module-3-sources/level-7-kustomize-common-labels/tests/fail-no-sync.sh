#!/bin/bash
# Wrong: the right change in Git, but never synced. The cluster still runs the old pods.
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
- pairs: {team: ledger, cost-center: cc-4711}
  includeSelectors: false
  includeTemplates: true
YAML
am_player_push "$SANDBOX/ledger-api" "labels without selectors"
am_argocd app get ledger-api --refresh >/dev/null

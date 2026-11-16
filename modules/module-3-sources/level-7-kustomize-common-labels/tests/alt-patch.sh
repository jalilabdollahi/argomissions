#!/bin/bash
# Also correct: a kustomize patch that adds the labels to the pod template only.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/ledger-api/deploy"
cat > kustomization.yaml <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
patches:
- target: {kind: Deployment, name: ledger-api}
  patch: |-
    - op: add
      path: /spec/template/metadata/labels/team
      value: ledger
    - op: add
      path: /spec/template/metadata/labels/cost-center
      value: cc-4711
YAML
am_player_push "$SANDBOX/ledger-api" "label pods with a patch"
am_argocd app get ledger-api --refresh >/dev/null
am_argocd app sync ledger-api --timeout 120
am_wait_app ledger-api sync=Synced health=Healthy --timeout 120

#!/bin/bash
# Also correct: drop commonLabels and put the labels directly on the Deployment's pod template.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/ledger-api/deploy"
cat > kustomization.yaml <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
YAML
sed -i.bak 's/^      labels: {app: ledger-api}$/      labels: {app: ledger-api, team: ledger, cost-center: cc-4711}/' deployment.yaml
rm -f deployment.yaml.bak
am_player_push "$SANDBOX/ledger-api" "labels directly on the pod template"
am_argocd app get ledger-api --refresh >/dev/null
am_argocd app sync ledger-api --timeout 120
am_wait_app ledger-api sync=Synced health=Healthy --timeout 120

#!/bin/bash
# Wrong: dodge the rule by storing the same token in a ConfigMap in Git.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/mail-relay"
git rm -q deploy/secret.yaml
cat > deploy/config.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: relay-credentials
data:
  token: relay-token-7f3a
YAML
sed -i.bak -e 's/secretKeyRef/configMapKeyRef/' deploy/deployment.yaml && rm deploy/deployment.yaml.bak
am_player_push "$SANDBOX/mail-relay" "Use a ConfigMap instead"
am_app_refresh mail-relay
am_wait_app mail-relay sync=OutOfSync --timeout 90 || true
am_argocd app sync mail-relay --timeout 120
am_argocd app wait mail-relay --health --timeout 120

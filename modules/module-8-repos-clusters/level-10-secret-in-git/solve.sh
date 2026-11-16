#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# 1. take the Secret out of Git (history stays)
cd "$SANDBOX/smtp-gateway"
git rm -q deploy/secret.yaml
am_player_push . "Remove SMTP credentials from Git"
am_argocd app get smtp-gateway --hard-refresh >/dev/null
am_wait_app smtp-gateway sync=OutOfSync --timeout 60 || true
# 2. prune the Secret Argo CD owned, then create it out of band with a new password
am_argocd app sync smtp-gateway --prune --timeout 120
newpass="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
kubectl -n smtp-gw create secret generic smtp-credentials --from-literal=username=mailer --from-literal=password="$newpass" >/dev/null
# 3. restart the pods so they read it
kubectl -n smtp-gw rollout restart deploy/smtp-gateway >/dev/null
kubectl -n smtp-gw rollout status deploy/smtp-gateway --timeout=120s
am_wait_app smtp-gateway sync=Synced health=Healthy --timeout 90

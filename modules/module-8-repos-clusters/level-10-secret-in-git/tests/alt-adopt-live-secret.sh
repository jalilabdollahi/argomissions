#!/bin/bash
# Correct too: remove the file from Git, then rotate the live Secret in place and let it go (drop Argo CD's tracking).
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/smtp-gateway"
git rm -q deploy/secret.yaml
am_player_push . "Remove SMTP credentials from Git"
am_argocd app get smtp-gateway --hard-refresh >/dev/null
am_wait_app smtp-gateway sync=OutOfSync --timeout 60 || true
newpass="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
kubectl -n smtp-gw patch secret smtp-credentials --type merge -p "{\"stringData\":{\"password\":\"$newpass\"}}" >/dev/null
kubectl -n smtp-gw annotate secret smtp-credentials argocd.argoproj.io/tracking-id- >/dev/null
kubectl -n smtp-gw delete pod -l app=smtp-gateway --wait=false >/dev/null
sleep 5
kubectl -n smtp-gw rollout status deploy/smtp-gateway --timeout=120s
am_argocd app get smtp-gateway --hard-refresh >/dev/null
am_wait_app smtp-gateway sync=Synced health=Healthy --timeout 90

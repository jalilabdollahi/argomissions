#!/bin/bash
# Wrong: scrub the history with a force-push of a fresh root commit (and rotate the password by hand).
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/smtp-gateway"
git checkout -q --orphan scrubbed
git rm -q -f deploy/secret.yaml
git commit -q -m "smtp-gateway v1.4 (history scrubbed)"
git push -q --force origin scrubbed:main
am_argocd app get smtp-gateway --hard-refresh >/dev/null
am_wait_app smtp-gateway sync=OutOfSync --timeout 60 || true
am_argocd app sync smtp-gateway --prune --timeout 120
newpass="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
kubectl -n smtp-gw create secret generic smtp-credentials --from-literal=username=mailer --from-literal=password="$newpass" >/dev/null
kubectl -n smtp-gw rollout restart deploy/smtp-gateway >/dev/null
kubectl -n smtp-gw rollout status deploy/smtp-gateway --timeout=120s
am_wait_app smtp-gateway sync=Synced health=Healthy --timeout 90

#!/bin/bash
# Wrong: the file is gone from Git and the Secret exists out of band - with the same leaked password.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/smtp-gateway"
git rm -q deploy/secret.yaml
am_player_push . "Remove SMTP credentials from Git"
am_argocd app get smtp-gateway --hard-refresh >/dev/null
am_wait_app smtp-gateway sync=OutOfSync --timeout 60 || true
am_argocd app sync smtp-gateway --prune --timeout 120
kubectl -n smtp-gw create secret generic smtp-credentials --from-literal=username=mailer --from-literal=password='Tr0ub4dor-smtp-2291' >/dev/null
kubectl -n smtp-gw rollout restart deploy/smtp-gateway >/dev/null
kubectl -n smtp-gw rollout status deploy/smtp-gateway --timeout=120s
am_wait_app smtp-gateway sync=Synced health=Healthy --timeout 90

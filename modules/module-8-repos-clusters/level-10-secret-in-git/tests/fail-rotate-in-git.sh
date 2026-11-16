#!/bin/bash
# Wrong: "rotate" by committing a new plaintext password to the same Secret manifest.
set -euo pipefail
source "$AM_LIB"

cd "$SANDBOX/smtp-gateway"
sed -i.bak 's/Tr0ub4dor-smtp-2291/N3w-Pa55-from-Git-8841/' deploy/secret.yaml && rm -f deploy/secret.yaml.bak
am_player_push . "Rotate SMTP password"
am_argocd app get smtp-gateway --hard-refresh >/dev/null
am_wait_app smtp-gateway sync=Synced health=Healthy --timeout 90
kubectl -n smtp-gw rollout restart deploy/smtp-gateway >/dev/null
kubectl -n smtp-gw rollout status deploy/smtp-gateway --timeout=120s

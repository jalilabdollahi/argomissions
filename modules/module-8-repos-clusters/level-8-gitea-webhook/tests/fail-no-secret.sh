#!/bin/bash
# Wrong: delete the secrets so Argo CD takes everything: deliveries work, but nobody is authenticated.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch secret argocd-secret --type json \
  -p '[{"op":"remove","path":"/data/webhook.gogs.secret"},{"op":"remove","path":"/data/webhook.gitea.secret"}]' >/dev/null
sleep 12

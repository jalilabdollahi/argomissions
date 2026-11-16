#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# new token for the machine user (Gitea UI: Settings > Applications), then store it
token="$(curl -fsS -X POST -u argo-reader:reader-pass-8Jt3 -H 'Content-Type: application/json' \
  -d '{"name":"argocd-2026-q4","scopes":["read:repository"]}' "$AM_GIT_HOST/api/v1/users/argo-reader/tokens" | jq -r .sha1)"
am_argocd repo add "$(am_repo_url mailroom)" --username argo-reader --password "$token" --upsert
am_argocd app get mailroom --hard-refresh >/dev/null
am_wait_app mailroom sync=Synced health=Healthy --timeout 150

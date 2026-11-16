#!/bin/bash
# Wrong: a new token is created in Gitea but never stored in Argo CD.
set -euo pipefail
source "$AM_LIB"

curl -fsS -X POST -u argo-reader:reader-pass-8Jt3 -H 'Content-Type: application/json' \
  -d '{"name":"argocd-unused","scopes":["read:repository"]}' "$AM_GIT_HOST/api/v1/users/argo-reader/tokens" >/dev/null
am_argocd app get mailroom --hard-refresh >/dev/null 2>&1 || true
sleep 5

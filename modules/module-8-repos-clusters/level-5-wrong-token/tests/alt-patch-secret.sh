#!/bin/bash
# Correct too: keep the Secret and patch the password key with a fresh token.
set -euo pipefail
source "$AM_LIB"

token="$(curl -fsS -X POST -u argo-reader:reader-pass-8Jt3 -H 'Content-Type: application/json' \
  -d '{"name":"argocd-rotated","scopes":["read:repository"]}' "$AM_GIT_HOST/api/v1/users/argo-reader/tokens" | jq -r .sha1)"
kubectl -n argocd patch secret repo-mailroom --type merge -p "{\"stringData\":{\"password\":\"$token\"}}"
am_argocd app get mailroom --hard-refresh >/dev/null
am_wait_app mailroom sync=Synced health=Healthy --timeout 150

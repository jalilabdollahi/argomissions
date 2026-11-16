#!/bin/bash
# Wrong: a repository entry exists but its password is wrong, so the app still cannot read Git.
set -euo pipefail
source "$AM_LIB"

am_argocd repo add "$(am_repo_url vault-ui)" --username argo-reader --password not-the-password --upsert >/dev/null 2>&1 || true
kubectl -n argocd create secret generic repo-vault-ui-bad \
  --from-literal=type=git --from-literal=url="$(am_repo_url vault-ui)" \
  --from-literal=username=argo-reader --from-literal=password=not-the-password
kubectl -n argocd label secret repo-vault-ui-bad argocd.argoproj.io/secret-type=repository
am_argocd app get vault-ui --hard-refresh >/dev/null 2>&1 || true
sleep 5

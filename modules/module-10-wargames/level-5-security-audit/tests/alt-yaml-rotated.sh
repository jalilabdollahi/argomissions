#!/bin/bash
# Correct too: the credential template as a YAML Secret, the whitelist through the CLI, and the Secret removed from
# Git with a fresh password created by `kubectl create secret`.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
fix_access
am_gitea PUT /repos/platform/custody-batch/collaborators/argo-reader '{"permission":"read"}' >/dev/null
kubectl -n argocd delete secret repo-custody-api repo-custody-batch >/dev/null
kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: creds-platform-org
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: $AM_GIT_INCLUSTER/platform
  username: argo-reader
  password: reader-pass-8Rt3
YAML
am_argocd proj allow-cluster-resource custody rbac.authorization.k8s.io ClusterRole >/dev/null
am_argocd proj allow-cluster-resource custody rbac.authorization.k8s.io ClusterRoleBinding >/dev/null
am_argocd proj deny-cluster-resource custody '*' '*' >/dev/null
cd "$SANDBOX/custody-api"; git pull -q
git rm -q deploy/db-secret.yaml
push_api "no secrets in Git"
kubectl -n custody create secret generic custody-db --from-literal=password="rot4ted-$(date +%s)-x9Zq" >/dev/null
kubectl -n custody delete pod -l app=custody-api --wait=false >/dev/null
settle

#!/bin/bash
# Wrong: the default is made read-only (and kim admin) but the pipeline gets no role; the rest is fixed properly.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.default":"role:readonly","policy.csv":"g, kim, role:admin\n"}}' >/dev/null
fix_creds; fix_project
cd "$SANDBOX/custody-api"; git pull -q
git rm -q deploy/db-secret.yaml
push_api "db secret out of Git"
kubectl -n custody create secret generic custody-db --from-literal=password="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n custody delete pod -l app=custody-api --wait=false >/dev/null
settle

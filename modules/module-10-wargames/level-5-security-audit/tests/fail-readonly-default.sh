#!/bin/bash
# Wrong: the pipeline gets its role, but the default is `role:readonly`, which every account (the pipeline too) inherits:
# deploy-bot can still read clusters and repositories. The other findings are fixed properly.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.default":"role:readonly","policy.csv":"p, role:custody-deployer, applications, get, custody/*, allow\np, role:custody-deployer, applications, sync, custody/*, allow\ng, kim, role:admin\ng, deploy-bot, role:custody-deployer\n"}}' >/dev/null
fix_creds; fix_project
cd "$SANDBOX/custody-api"; git pull -q
git rm -q deploy/db-secret.yaml
push_api "db secret out of Git"
kubectl -n custody create secret generic custody-db --from-literal=password="rot4ted-$(date +%s)-q7Lm" >/dev/null
kubectl -n custody delete pod -l app=custody-api --wait=false >/dev/null
settle

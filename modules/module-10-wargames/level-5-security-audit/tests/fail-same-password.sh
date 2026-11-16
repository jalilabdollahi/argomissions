#!/bin/bash
# Wrong: the manifest leaves Git and the Secret is re-created by hand with the SAME (leaked) password.
set -euo pipefail
source "$AM_LIB"; source "$LEVEL_DIR/assets/testlib.sh"
fix_access; fix_creds; fix_project
cd "$SANDBOX/custody-api"; git pull -q
git rm -q deploy/db-secret.yaml
push_api "db secret out of Git"
kubectl -n custody create secret generic custody-db --from-literal=password='Summer2024!db' --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n custody delete pod -l app=custody-api --wait=false >/dev/null
settle

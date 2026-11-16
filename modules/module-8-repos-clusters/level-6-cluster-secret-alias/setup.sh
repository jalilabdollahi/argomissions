#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed boarding-pass "$LEVEL_DIR/repo" "boarding-pass v3.1 manifests"
kubectl create namespace boarding-stg >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/rbac.yaml" >/dev/null

have_token() { [ -n "$(kubectl -n boarding-stg get secret argocd-deployer-token -o jsonpath='{.data.token}')" ]; }
am_wait 60 have_token || { echo "setup: ServiceAccount token was not issued"; exit 1; }
TOKEN="$(kubectl -n boarding-stg get secret argocd-deployer-token -o jsonpath='{.data.token}' | base64 -d)"

# The colleague registered the cluster by hand and forgot the CA: no tlsClientConfig at all.
kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: cluster-staging
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
stringData:
  name: staging
  server: https://kubernetes.default.svc.cluster.local
  namespaces: boarding-stg
  config: '{"bearerToken":"$TOKEN"}'
YAML

am_app_apply "$LEVEL_DIR/assets/app.yaml"
am_app_refresh boarding-pass
x509() { am_app_conditions boarding-pass | grep -q 'x509: certificate signed by unknown authority'; }
am_wait 90 x509 || { echo "setup: Argo CD did not report the x509 error"; exit 1; }
am_setup_assert "nothing deployed to boarding-stg" bash -c '[ -z "$(kubectl -n boarding-stg get deploy -o name)" ]'

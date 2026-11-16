#!/bin/bash
set -euo pipefail
source "$AM_LIB"

am_repo_seed parcel-hub "$LEVEL_DIR/repo" "parcel-hub v2.0 manifests"
kubectl create namespace parcel-eu >/dev/null
kubectl create namespace parcel-us >/dev/null
kubectl apply -f "$LEVEL_DIR/assets/rbac.yaml" >/dev/null

have_token() { [ -n "$(kubectl -n parcel-eu get secret argocd-regional-token -o jsonpath='{.data.token}')" ]; }
am_wait 60 have_token || { echo "setup: ServiceAccount token was not issued"; exit 1; }
TOKEN="$(kubectl -n parcel-eu get secret argocd-regional-token -o jsonpath='{.data.token}' | base64 -d)"
CA="$(kubectl -n parcel-eu get secret argocd-regional-token -o jsonpath='{.data.ca\.crt}')"

# Registered when only the EU region existed: the scope lists parcel-eu alone.
kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: cluster-regional
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
stringData:
  name: regional
  server: https://kubernetes.default.svc.cluster.local
  namespaces: parcel-eu
  config: '{"bearerToken":"$TOKEN","tlsClientConfig":{"insecure":false,"caData":"$CA"}}'
YAML

am_app_apply "$LEVEL_DIR/assets/apps.yaml"
am_app_refresh parcel-hub-eu
am_app_refresh parcel-hub-us
am_wait_app parcel-hub-eu sync=Synced health=Healthy --timeout 150 \
  || { echo "setup: parcel-hub-eu did not become healthy"; exit 1; }
unmanaged() { am_app_conditions parcel-hub-us | grep -q 'namespace "parcel-us" for Deployment "parcel-hub" is not managed'; }
am_wait 90 unmanaged || { echo "setup: Argo CD did not report the unmanaged namespace"; exit 1; }

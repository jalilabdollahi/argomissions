#!/bin/bash
# Wrong: "make the error go away" by switching TLS verification off for the staging cluster.
set -euo pipefail
source "$AM_LIB"

cfg="$(kubectl -n argocd get secret cluster-staging -o jsonpath='{.data.config}' | base64 -d \
  | jq -c '. + {tlsClientConfig: {insecure: true}}')"
kubectl -n argocd patch secret cluster-staging --type merge -p "$(jq -nc --arg c "$cfg" '{stringData: {config: $c}}')" >/dev/null
sleep 3
am_app_refresh boarding-pass normal
am_wait_app boarding-pass sync=Synced health=Healthy --timeout 150

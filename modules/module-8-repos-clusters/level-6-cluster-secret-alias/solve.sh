#!/bin/bash
set -euo pipefail
source "$AM_LIB"

CA="$(kubectl -n boarding-stg get secret argocd-deployer-token -o jsonpath='{.data.ca\.crt}')"
cfg="$(kubectl -n argocd get secret cluster-staging -o jsonpath='{.data.config}' | base64 -d \
  | jq -c --arg ca "$CA" '. + {tlsClientConfig: {insecure: false, caData: $ca}}')"
kubectl -n argocd patch secret cluster-staging --type merge -p "$(jq -nc --arg c "$cfg" '{stringData: {config: $c}}')" >/dev/null
sleep 3
am_app_refresh boarding-pass normal
am_wait_app boarding-pass sync=Synced health=Healthy --timeout 150

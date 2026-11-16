#!/bin/bash
# Correct too: take the CA from the kube-root-ca.crt ConfigMap that exists in every namespace.
set -euo pipefail
source "$AM_LIB"

CA="$(kubectl -n boarding-stg get cm kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' | base64 | tr -d '\n')"
TOKEN="$(kubectl -n boarding-stg get secret argocd-deployer-token -o jsonpath='{.data.token}' | base64 -d)"
cfg="$(jq -nc --arg t "$TOKEN" --arg ca "$CA" '{bearerToken: $t, tlsClientConfig: {insecure: false, caData: $ca}}')"
kubectl -n argocd patch secret cluster-staging --type merge -p "$(jq -nc --arg c "$cfg" '{stringData: {config: $c}}')" >/dev/null
sleep 3
am_argocd app get boarding-pass --hard-refresh >/dev/null
am_wait_app boarding-pass sync=Synced health=Healthy --timeout 150

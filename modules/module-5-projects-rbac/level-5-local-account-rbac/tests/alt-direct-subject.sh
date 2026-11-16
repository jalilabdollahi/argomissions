#!/bin/bash
# Correct too: policy lines naming the account directly, with no role in between.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.csv":"p, ci-bot, applications, get, shop/*, allow\np, ci-bot, applications, sync, shop/*, allow\n"}}'
sleep 5

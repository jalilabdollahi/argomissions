#!/bin/bash
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.csv":"p, role:shop-deployer, applications, get, shop/*, allow\np, role:shop-deployer, applications, sync, shop/*, allow\ng, ci-bot, role:shop-deployer\n"}}'

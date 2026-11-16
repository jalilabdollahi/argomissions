#!/bin/bash
# Wrong: sync and get on every project.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.csv":"p, ci-bot, applications, get, */*, allow\np, ci-bot, applications, sync, */*, allow\n"}}'
sleep 5

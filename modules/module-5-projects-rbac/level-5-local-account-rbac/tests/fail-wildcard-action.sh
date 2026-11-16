#!/bin/bash
# Wrong: every action on the shop's applications (includes delete and update).
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.csv":"p, ci-bot, applications, *, shop/*, allow\n"}}'
sleep 5

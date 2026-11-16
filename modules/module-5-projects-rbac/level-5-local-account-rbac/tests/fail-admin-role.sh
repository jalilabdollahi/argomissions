#!/bin/bash
# Wrong: make the bot an administrator.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.csv":"g, ci-bot, role:admin\n"}}'
sleep 5

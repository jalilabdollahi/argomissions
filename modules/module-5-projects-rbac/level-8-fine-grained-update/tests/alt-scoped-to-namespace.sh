#!/bin/bash
# Correct too: Pod deletion limited to the application's namespace, written as a policy of the user instead of the role.
set -euo pipefail
source "$AM_LIB"

csv="$(kubectl -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.policy\.csv}')
p, mira, applications, action/apps/Deployment/restart, loyalty/rewards-engine, allow
p, mira, applications, delete/*/Pod/rewards/*, loyalty/rewards-engine, allow"
kubectl -n argocd patch cm argocd-rbac-cm --type merge -p "$(jq -nc --arg c "$csv" '{data:{"policy.csv":$c}}')" >/dev/null
sleep 4

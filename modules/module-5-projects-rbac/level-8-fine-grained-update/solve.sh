#!/bin/bash
set -euo pipefail
source "$AM_LIB"

csv="$(kubectl -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.policy\.csv}')"
csv="$csv
p, role:loyalty-oncall, applications, action/apps/Deployment/restart, loyalty/*, allow
p, role:loyalty-oncall, applications, delete/*/Pod/*/*, loyalty/*, allow"
kubectl -n argocd patch cm argocd-rbac-cm --type merge -p "$(jq -nc --arg c "$csv" '{data:{"policy.csv":$c}}')" >/dev/null
sleep 4

#!/bin/bash
# Wrong: everything under delete and action is opened up. On-call works again, and so can she delete Secrets or scale.
set -euo pipefail
source "$AM_LIB"

csv="$(kubectl -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.policy\.csv}')
p, role:loyalty-oncall, applications, action/*, loyalty/*, allow
p, role:loyalty-oncall, applications, delete/*, loyalty/*, allow"
kubectl -n argocd patch cm argocd-rbac-cm --type merge -p "$(jq -nc --arg c "$csv" '{data:{"policy.csv":$c}}')" >/dev/null
sleep 4

#!/bin/bash
# Wrong: mira is simply made an administrator.
set -euo pipefail
source "$AM_LIB"

csv="$(kubectl -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.policy\.csv}')
g, mira, role:admin"
kubectl -n argocd patch cm argocd-rbac-cm --type merge -p "$(jq -nc --arg c "$csv" '{data:{"policy.csv":$c}}')" >/dev/null
sleep 4

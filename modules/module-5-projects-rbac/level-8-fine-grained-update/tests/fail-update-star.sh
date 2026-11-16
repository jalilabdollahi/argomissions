#!/bin/bash
# Wrong: the documentation says update/delete became fine-grained, so `update/*` is added. It covers patching
# resources, but neither the restart action nor deleting Pods.
set -euo pipefail
source "$AM_LIB"

csv="$(kubectl -n argocd get cm argocd-rbac-cm -o jsonpath='{.data.policy\.csv}')
p, role:loyalty-oncall, applications, update/*, loyalty/*, allow"
kubectl -n argocd patch cm argocd-rbac-cm --type merge -p "$(jq -nc --arg c "$csv" '{data:{"policy.csv":$c}}')" >/dev/null
sleep 4

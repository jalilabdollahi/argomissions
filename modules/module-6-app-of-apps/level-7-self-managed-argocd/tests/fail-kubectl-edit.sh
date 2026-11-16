#!/bin/bash
# Wrong: the permission added with kubectl again. Self-heal reverts it.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd get configmap argocd-rbac-cm -o jsonpath='{.data.policy\.csv}' >"$AM_TMP/p.csv"
printf 'p, role:oncall, applications, sync, default/*, allow\ng, payments-oncall, role:oncall\n' >>"$AM_TMP/p.csv"
kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p "$(jq -n --rawfile c "$AM_TMP/p.csv" '{data:{"policy.csv":$c}}')"
reverted() { ! kubectl -n argocd get configmap argocd-rbac-cm -o jsonpath='{.data.policy\.csv}' | grep -q payments-oncall; }
am_wait 120 reverted || true

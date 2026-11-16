#!/bin/bash
# Wrong: self-heal is switched off so that the manual edit survives. Git still says nothing; the app is OutOfSync.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application argocd-settings --type merge -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false}}}}'
sleep 3
kubectl -n argocd get configmap argocd-rbac-cm -o jsonpath='{.data.policy\.csv}' >"$AM_TMP/p.csv"
printf 'p, role:oncall, applications, sync, default/*, allow\ng, payments-oncall, role:oncall\n' >>"$AM_TMP/p.csv"
kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p "$(jq -n --rawfile c "$AM_TMP/p.csv" '{data:{"policy.csv":$c}}')"
am_app_refresh argocd-settings
am_wait_app argocd-settings sync=OutOfSync --timeout 60

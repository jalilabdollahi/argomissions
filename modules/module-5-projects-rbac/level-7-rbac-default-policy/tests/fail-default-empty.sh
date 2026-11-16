#!/bin/bash
# Wrong: the default policy is removed altogether, and alice gets admin. Nobody else can even look at the Applications.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-rbac-cm --type merge \
  -p '{"data":{"policy.default":"","policy.csv":"g, alice, role:admin\n"}}' >/dev/null
sleep 4

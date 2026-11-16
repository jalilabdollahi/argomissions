#!/bin/bash
# Wrong: "fixed" by giving every account an explicit admin line and changing only the default.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-rbac-cm --type merge \
  -p '{"data":{"policy.default":"role:readonly","policy.csv":"g, alice, role:admin\ng, bob, role:admin\n"}}' >/dev/null
sleep 4

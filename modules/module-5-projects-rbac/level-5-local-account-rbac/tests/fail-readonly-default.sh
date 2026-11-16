#!/bin/bash
# Wrong: a read-only default policy; the bot can look at everything and still cannot sync.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.default":"role:readonly"}}'
sleep 5

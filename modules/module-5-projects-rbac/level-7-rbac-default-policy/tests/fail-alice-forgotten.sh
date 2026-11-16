#!/bin/bash
# Wrong: the default is locked to readonly but the platform lead was forgotten, she is read-only now too.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-rbac-cm --type merge -p '{"data":{"policy.default":"role:readonly"}}' >/dev/null
sleep 4

#!/bin/bash
# Correct too: no role binding, alice gets explicit policy lines; the default stays the built-in read-only role.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch configmap argocd-rbac-cm --type merge \
  -p '{"data":{"policy.default":"role:readonly","policy.csv":"p, alice, *, *, */*, allow\np, alice, clusters, *, *, allow\np, alice, projects, *, *, allow\n"}}' >/dev/null
sleep 4

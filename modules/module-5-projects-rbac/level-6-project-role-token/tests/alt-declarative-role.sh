#!/bin/bash
# Correct too: the role and its policies written into the AppProject manifest, the token created afterwards.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch appproject settlements --type merge -p '{"spec":{"roles":[{"name":"deployer",
  "description":"release pipeline","policies":[
  "p, proj:settlements:deployer, applications, get, settlements/*, allow",
  "p, proj:settlements:deployer, applications, sync, settlements/*, allow"]}]}}' >/dev/null
token="$(am_argocd proj role create-token settlements deployer --token-only)"
kubectl -n settle-ci patch secret argocd-pipeline-token --type merge \
  -p "{\"stringData\":{\"token\":\"$token\"}}" >/dev/null

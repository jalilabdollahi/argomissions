#!/bin/bash
# Correct too: ignoreDifferences with a jq expression, written with kubectl.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application quote-api --type merge -p '{"spec":{
  "ignoreDifferences":[{"group":"apps","kind":"Deployment","name":"quote-api","jqPathExpressions":[".spec.replicas"]}],
  "syncPolicy":{"syncOptions":["RespectIgnoreDifferences=true"]}}}'
am_wait_app quote-api sync=Synced health=Healthy --timeout 150

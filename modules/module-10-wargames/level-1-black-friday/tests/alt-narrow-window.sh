#!/bin/bash
# Correct too: the freeze is narrowed to its real hours (an allowed manual sync is not required then), the replica
# field is excluded through a jq expression, and promo is synced.
set -euo pipefail
source "$AM_LIB"

am_argocd proj windows delete blackfriday 0
am_argocd proj windows add blackfriday --kind deny --schedule '0 0 1 1 *' --duration 1h \
  --applications '*' --namespaces '*' --clusters '*'
am_argocd proj add-destination blackfriday https://kubernetes.default.svc bf-promo
am_argocd proj allow-cluster-resource blackfriday '' Namespace
kubectl -n argocd patch application bf-cart --type merge -p '{"spec":{
  "ignoreDifferences":[{"group":"apps","kind":"Deployment","name":"bf-cart","jqPathExpressions":[".spec.replicas"]}],
  "syncPolicy":{"syncOptions":["RespectIgnoreDifferences=true"]}}}'
am_wait_app bf-cart sync=Synced health=Healthy --timeout 150
am_wait 60 bash -c '! kubectl -n argocd get application bf-promo -o json | grep -q InvalidSpecError'
am_argocd app get bf-promo --refresh >/dev/null
am_argocd app sync bf-promo --timeout 120
am_wait_app bf-promo sync=Synced health=Healthy --timeout 150

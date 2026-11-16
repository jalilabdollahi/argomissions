#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# Triage order: the freeze, then the project boundary, then the autoscaler fight, then ship both releases.
am_argocd proj windows list blackfriday
am_argocd proj windows enable-manual-sync blackfriday 0
am_argocd proj add-destination blackfriday https://kubernetes.default.svc bf-promo
am_argocd proj allow-cluster-resource blackfriday '' Namespace
am_argocd app patch bf-cart --type merge --patch '{"spec":{
  "ignoreDifferences":[{"group":"apps","kind":"Deployment","jsonPointers":["/spec/replicas"]}],
  "syncPolicy":{"syncOptions":["RespectIgnoreDifferences=true"]}}}'
am_argocd app sync bf-cart --timeout 120
am_wait_app bf-cart sync=Synced health=Healthy --timeout 150
am_wait 60 bash -c '! kubectl -n argocd get application bf-promo -o json | grep -q InvalidSpecError'
am_argocd app get bf-promo --refresh >/dev/null
am_argocd app sync bf-promo --timeout 120
am_wait_app bf-promo sync=Synced health=Healthy --timeout 150

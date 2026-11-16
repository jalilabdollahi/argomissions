#!/bin/bash
# Wrong: the cart is fixed and shipped, the banner is forgotten (it is "just a banner").
set -euo pipefail
source "$AM_LIB"

am_argocd proj windows enable-manual-sync blackfriday 0
am_argocd app patch bf-cart --type merge --patch '{"spec":{
  "ignoreDifferences":[{"group":"apps","kind":"Deployment","jsonPointers":["/spec/replicas"]}],
  "syncPolicy":{"syncOptions":["RespectIgnoreDifferences=true"]}}}'
am_argocd app sync bf-cart --timeout 120
am_wait_app bf-cart sync=Synced health=Healthy --timeout 150

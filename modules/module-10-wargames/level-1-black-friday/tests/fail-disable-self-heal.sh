#!/bin/bash
# Wrong: everything is fixed, but the autoscaler fight is "solved" by turning self-heal off for the whole app.
set -euo pipefail
source "$AM_LIB"

am_argocd proj windows enable-manual-sync blackfriday 0
am_argocd proj add-destination blackfriday https://kubernetes.default.svc bf-promo
am_argocd proj allow-cluster-resource blackfriday '' Namespace
am_argocd app set bf-cart --self-heal=false
am_argocd app sync bf-cart --timeout 120
am_wait 60 bash -c '! kubectl -n argocd get application bf-promo -o json | grep -q InvalidSpecError'
am_argocd app get bf-promo --refresh >/dev/null
am_argocd app sync bf-promo --timeout 120
am_wait_app bf-promo sync=Synced health=Healthy --timeout 150

#!/bin/bash
# Correct too: the element added with a JSON patch on the live ApplicationSet.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset geo-edge --type json \
  -p '[{"op":"add","path":"/spec/generators/0/list/elements/-","value":{"region":"eu-west"}}]'
am_wait_app geo-edge-eu-west sync=Synced health=Healthy --timeout 150

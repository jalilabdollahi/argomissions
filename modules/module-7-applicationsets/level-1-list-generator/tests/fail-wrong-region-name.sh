#!/bin/bash
# Wrong: an element is added, but with a region name that does not match the expected one.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset geo-edge --type json \
  -p '[{"op":"add","path":"/spec/generators/0/list/elements/-","value":{"region":"eu-west-1"}}]'
am_wait_app geo-edge-eu-west-1 sync=Synced health=Healthy --timeout 150

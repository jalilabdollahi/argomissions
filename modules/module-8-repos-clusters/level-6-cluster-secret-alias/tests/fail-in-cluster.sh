#!/bin/bash
# Wrong: skip the staging cluster and deploy through the built-in in-cluster destination.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application boarding-pass --type merge \
  -p '{"spec":{"destination":{"name":"in-cluster","namespace":"boarding-stg"}}}' >/dev/null
am_app_refresh boarding-pass normal
am_wait_app boarding-pass sync=Synced health=Healthy --timeout 150

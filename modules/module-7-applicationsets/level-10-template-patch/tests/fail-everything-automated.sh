#!/bin/bash
# Wrong: automated sync in the template for every environment; prod follows main, and so do the frozen rigs.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset lumen-gateway --type json -p '[
  {"op":"add","path":"/spec/template/spec/syncPolicy/automated","value":{"prune":true}}]'
am_wait_app lumen-prod sync=Synced health=Healthy --timeout 150
am_wait_app lumen-dev sync=Synced health=Healthy --timeout 150

#!/bin/bash
# Correct too: let the hub Application skip the dry run for a missing kind and start the CRD sync at the same
# time; the instance is applied once the CRD exists.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application sensor-hub --type merge \
  -p '{"spec":{"syncPolicy":{"syncOptions":["CreateNamespace=true","SkipDryRunOnMissingResource=true"]}}}'
am_app_sync_now sensor-crds
am_wait_app sensor-crds op=Succeeded sync=Synced health=Healthy --timeout 120
am_app_sync_now sensor-hub
am_wait_app sensor-hub op=Succeeded sync=Synced health=Healthy --timeout 120

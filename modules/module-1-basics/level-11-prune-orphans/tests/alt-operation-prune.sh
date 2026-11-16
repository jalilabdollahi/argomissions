#!/bin/bash
# Correct too: what the UI's Prune checkbox does, expressed as a raw sync operation with prune enabled.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application media --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"prune":true,"syncStrategy":{"hook":{}}}}}'
am_wait_app media sync=Synced health=Healthy --timeout 120

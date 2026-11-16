#!/bin/bash
# Correct too: prune enabled by patching the Application.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application gallery-web --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true}}}}'
am_wait_app gallery-web sync=Synced health=Healthy --timeout 120

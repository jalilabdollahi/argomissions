#!/bin/bash
# Correct too: the sync option written straight into the Application, synced from the CLI.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch application host-registry --type merge -p '{"spec":{"syncPolicy":{"syncOptions":["ServerSideApply=true"]}}}'
am_argocd app sync host-registry --timeout 120
am_wait_app host-registry sync=Synced health=Healthy --timeout 120

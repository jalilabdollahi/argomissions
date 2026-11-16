#!/bin/bash
set -euo pipefail
source "$AM_LIB"

A=(--kind Deployment --resource-name ferry-booking)
kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$LEVEL_DIR/assets/action-solution.yaml"
has_actions() { am_argocd app actions list ferry-booking "${A[@]}" | grep -q maintenance-on; }
am_wait 30 has_actions
am_argocd app actions run ferry-booking maintenance-on "${A[@]}"
am_wait_app ferry-booking sync=Synced health=Healthy --timeout 60

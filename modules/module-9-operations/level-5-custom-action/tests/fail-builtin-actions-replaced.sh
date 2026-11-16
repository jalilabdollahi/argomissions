#!/bin/bash
# Wrong: the custom actions work, but without mergeBuiltinActions the built-in restart/scale/pause are gone.
set -euo pipefail
source "$AM_LIB"

A=(--kind Deployment --resource-name ferry-booking)
grep -v mergeBuiltinActions "$LEVEL_DIR/assets/action-solution.yaml" >"$AM_TMP/cm.yaml"
kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$AM_TMP/cm.yaml"
has_actions() { am_argocd app actions list ferry-booking "${A[@]}" | grep -q maintenance-on; }
am_wait 30 has_actions
am_argocd app actions run ferry-booking maintenance-on "${A[@]}"

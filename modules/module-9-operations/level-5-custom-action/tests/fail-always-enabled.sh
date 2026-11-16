#!/bin/bash
# Wrong (lazy discovery): both actions are always enabled, whatever the Deployment's state.
set -euo pipefail
source "$AM_LIB"

A=(--kind Deployment --resource-name ferry-booking)
cat >"$AM_TMP/cm.yaml" <<'YAML'
data:
  resource.customizations.actions.apps_Deployment: |
    mergeBuiltinActions: true
    discovery.lua: |
      local actions = {}
      actions["maintenance-on"] = {["disabled"] = false}
      actions["maintenance-off"] = {["disabled"] = false}
      return actions
    definitions:
    - name: maintenance-on
      action.lua: |
        obj.metadata.annotations["ferry.argomissions.io/maintenance"] = "on"
        return obj
    - name: maintenance-off
      action.lua: |
        obj.metadata.annotations["ferry.argomissions.io/maintenance"] = nil
        return obj
YAML
kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$AM_TMP/cm.yaml"
has_actions() { am_argocd app actions list ferry-booking "${A[@]}" | grep -q maintenance-on; }
am_wait 30 has_actions
am_argocd app actions run ferry-booking maintenance-on "${A[@]}"

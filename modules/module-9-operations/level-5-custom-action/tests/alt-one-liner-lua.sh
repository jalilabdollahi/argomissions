#!/bin/bash
# Correct too: the same actions written with a helper function, and applied with `kubectl edit`-style replace of the key.
set -euo pipefail
source "$AM_LIB"

A=(--kind Deployment --resource-name ferry-booking)
cat >"$AM_TMP/cm.yaml" <<'YAML'
data:
  resource.customizations.actions.apps_Deployment: |
    mergeBuiltinActions: true
    discovery.lua: |
      local function flag(o)
        local a = o.metadata.annotations
        return a ~= nil and a["ferry.argomissions.io/maintenance"] == "on"
      end
      local actions = {}
      actions["maintenance-on"] = {["disabled"] = flag(obj)}
      actions["maintenance-off"] = {["disabled"] = not flag(obj)}
      return actions
    definitions:
    - name: maintenance-on
      action.lua: |
        local a = obj.metadata.annotations or {}
        a["ferry.argomissions.io/maintenance"] = "on"
        obj.metadata.annotations = a
        return obj
    - name: maintenance-off
      action.lua: |
        local a = obj.metadata.annotations or {}
        a["ferry.argomissions.io/maintenance"] = nil
        obj.metadata.annotations = a
        return obj
YAML
kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$AM_TMP/cm.yaml"
has_actions() { am_argocd app actions list ferry-booking "${A[@]}" | grep -q maintenance-on; }
am_wait 30 has_actions
am_argocd app actions run ferry-booking maintenance-on "${A[@]}"
am_wait_app ferry-booking sync=Synced health=Healthy --timeout 60

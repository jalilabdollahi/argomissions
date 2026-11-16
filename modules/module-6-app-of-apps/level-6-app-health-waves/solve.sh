#!/bin/bash
set -euo pipefail
source "$AM_LIB"

# 1. Teach Argo CD to read an Application's health.
cat >"$AM_TMP/health.yaml" <<'YAML'
data:
  resource.customizations.health.argoproj.io_Application: |
    hs = {}
    hs.status = "Progressing"
    hs.message = ""
    if obj.status ~= nil then
      if obj.status.health ~= nil then
        hs.status = obj.status.health.status
        if obj.status.health.message ~= nil then
          hs.message = obj.status.health.message
        end
      end
    end
    return hs
YAML
kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$AM_TMP/health.yaml"

# 2. Bring the platform up again from nothing, through the root.
for a in beacon-api beacon-db; do am_argocd app delete "$a" --cascade --yes; done
am_wait 90 bash -c '! kubectl -n argocd get application beacon-db beacon-api'
am_app_refresh beacon-root
am_wait_app beacon-root sync=OutOfSync --timeout 60
am_argocd app sync beacon-root --timeout 240
am_wait_app beacon-api sync=Synced health=Healthy --timeout 180
am_wait_app beacon-db sync=Synced health=Healthy --timeout 60
am_wait_app beacon-root sync=Synced health=Healthy --timeout 60

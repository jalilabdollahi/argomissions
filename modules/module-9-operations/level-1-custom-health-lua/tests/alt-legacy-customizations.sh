#!/bin/bash
# Correct too: the older combined `resource.customizations` key (group/Kind: health.lua).
set -euo pipefail
source "$AM_LIB"

cat >"$AM_TMP/cm.yaml" <<'YAML'
data:
  resource.customizations: |
    vaultline.argomissions.io/Backup:
      health.lua: |
        hs = {}
        local phase = ""
        if obj.status ~= nil and obj.status.phase ~= nil then phase = obj.status.phase end
        if phase == "Done" then
          hs.status = "Healthy"
        elseif phase == "Failed" then
          hs.status = "Degraded"
        else
          hs.status = "Progressing"
        end
        hs.message = phase
        return hs
YAML
kubectl -n argocd patch configmap argocd-cm --type merge --patch-file "$AM_TMP/cm.yaml"
am_app_refresh vaultline normal
sleep 8

# Walkthrough — A Button For Maintenance

1. **Look at the current actions.**
   ```bash
   argocd app actions list ferry-booking --kind Deployment --resource-name ferry-booking
   ```
   `scale`, `pause`, `restart`, `resume`: built in, nothing for maintenance.
2. **Define the actions in argocd-cm.** File `actions.yaml`:
   ```yaml
   data:
     resource.customizations.actions.apps_Deployment: |
       mergeBuiltinActions: true
       discovery.lua: |
         local actions = {}
         local on = false
         if obj.metadata.annotations ~= nil and obj.metadata.annotations["ferry.argomissions.io/maintenance"] == "on" then
           on = true
         end
         actions["maintenance-on"] = {["disabled"] = on}
         actions["maintenance-off"] = {["disabled"] = not on}
         return actions
       definitions:
       - name: maintenance-on
         action.lua: |
           if obj.metadata.annotations == nil then
             obj.metadata.annotations = {}
           end
           obj.metadata.annotations["ferry.argomissions.io/maintenance"] = "on"
           return obj
       - name: maintenance-off
         action.lua: |
           if obj.metadata.annotations ~= nil then
             obj.metadata.annotations["ferry.argomissions.io/maintenance"] = nil
           end
           return obj
   ```
   ```bash
   kubectl -n argocd patch configmap argocd-cm --type merge --patch-file actions.yaml
   ```
   `mergeBuiltinActions: true` keeps `restart` and friends; without it only your two actions would be listed.
3. **List again.** `maintenance-off` is disabled (nothing to switch off), `maintenance-on` is enabled, `restart`
   is still there. No restart of Argo CD is needed.
4. **Press the button.**
   ```bash
   argocd app actions run ferry-booking maintenance-on --kind Deployment --resource-name ferry-booking
   kubectl -n ferry get deploy ferry-booking -o jsonpath='{.metadata.annotations}'
   argocd app actions list ferry-booking --kind Deployment --resource-name ferry-booking   # flipped
   argocd app get ferry-booking                                                              # still Synced
   ```

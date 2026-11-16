# Walkthrough — Green Dashboard, Red Backups

1. **Compare what Argo CD says with what the operator says.**
   ```bash
   argocd app get vaultline                      # Health Status: Healthy, HEALTH column of the Backups empty
   kubectl -n vaultline get backups              # PHASE: Failed / Done / Running
   kubectl -n vaultline get backup nightly-ledger -o jsonpath='{.status}'
   ```
   The operator writes `.status.phase` and `.status.message`. Argo CD does not look at them.
2. **Write the health check.** Argo CD finds custom health checks in `argocd-cm`, key
   `resource.customizations.health.<group>_<Kind>`. Put the Lua in a file `cm-patch.yaml`:
   ```yaml
   data:
     resource.customizations.health.vaultline.argomissions.io_Backup: |
       hs = {}
       if obj.status ~= nil and obj.status.phase ~= nil then
         if obj.status.phase == "Done" then
           hs.status = "Healthy"
         elseif obj.status.phase == "Failed" then
           hs.status = "Degraded"
         else
           hs.status = "Progressing"
         end
         hs.message = obj.status.message
         return hs
       end
       hs.status = "Progressing"
       hs.message = "Waiting for the vaultline operator"
       return hs
   ```
3. **Test it offline (optional).**
   ```bash
   kubectl -n vaultline get backup nightly-ledger -o yaml > b.yaml
   kubectl -n argocd get cm argocd-cm -o yaml > cm.yaml        # with the new key added
   argocd admin settings resource-overrides health b.yaml --argocd-cm-path cm.yaml
   ```
4. **Apply it.** `kubectl -n argocd patch configmap argocd-cm --type merge --patch-file cm-patch.yaml`
   (or `kubectl edit`). The controller reads argocd-cm live, no restart. Applications are re-evaluated on the
   next refresh: `argocd app get vaultline --refresh`.
5. **Verify.** `argocd app get vaultline` now shows Backup `nightly-ledger` Degraded, `weekly-archive` Healthy,
   `hourly-journal` Progressing, and the application Degraded. That is the truth; the failed upload is still a
   problem for the vaultline team, but now somebody can see it.

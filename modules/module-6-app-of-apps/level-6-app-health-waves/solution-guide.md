# Walkthrough — Waves That Do Not Wait

1. **See the symptom.**
   ```bash
   argocd app get beacon-root
   kubectl -n argocd get applications -o custom-columns=NAME:.metadata.name,CREATED:.metadata.creationTimestamp
   kubectl -n beacon-data get deploy beacon-db -o jsonpath='{.status.conditions[?(@.type=="Available")].lastTransitionTime}'
   ```
   `beacon-api` was created about 25 seconds before the database deployment became available. The root lists
   the two child Applications as `Synced` and shows **no health** for them.
2. **Understand it.** A sync wave starts only when every resource of the previous wave is Healthy. Argo CD has a
   built-in health check for Deployments, Jobs, Ingresses ... but not for `argoproj.io/Application`: it is
   treated as Healthy the moment it exists (it has been that way since Argo CD 1.8). Wave 2 therefore started
   immediately.
3. **Teach Argo CD to read an Application's health.** Add this key to ConfigMap `argocd-cm` in `argocd`:
   ```bash
   kubectl -n argocd edit configmap argocd-cm
   ```
   ```yaml
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
   ```
   The config is read dynamically, no restart is needed. Check the script with
   `argocd admin settings resource-overrides health <file> --load-cluster-settings`.
4. **Replay the bring-up.** Waves only apply while a sync runs, so tear the children down and sync the root again:
   ```bash
   argocd app delete beacon-api --cascade --yes
   argocd app delete beacon-db --cascade --yes
   argocd app sync beacon-root
   ```
   Watch `argocd app get beacon-root`: `beacon-db` is created, the root sync waits while it is `Progressing`, and
   only then `beacon-api` appears.
5. **Verify.** `argocd app list` shows all three Applications Synced and Healthy; the creation time of
   `beacon-api` is later than the `Available` transition of the `beacon-db` Deployment. Run `check`.

# Walkthrough — Fighting The Autoscaler

1. **Observe the fight.**
   ```bash
   argocd app get quote-api            # OutOfSync, Automated operations
   argocd app diff quote-api           # replicas: 2 (Git) vs 4 (live)
   kubectl -n quotes get deploy quote-api -w
   ```
   `kubectl get deploy quote-api --show-managed-fields -o yaml` shows two managers writing `spec.replicas`:
   Argo CD's applier and `load-scaler`.
2. **Reject the shortcuts.** `argocd app set quote-api --self-heal=false` stops the revert but leaves the app
   `OutOfSync` and drops drift protection; deleting `load-scaler` breaks the other team's autoscaling.
3. **Make replicas the autoscaler's field.** Edit the Application (it is the object that needs to change):
   ```bash
   argocd app patch quote-api --type merge --patch '{"spec":{
     "ignoreDifferences":[{"group":"apps","kind":"Deployment","jsonPointers":["/spec/replicas"]}],
     "syncPolicy":{"syncOptions":["RespectIgnoreDifferences=true"]}}}'
   ```
   (YAML: `spec.ignoreDifferences` plus `syncPolicy.syncOptions: [RespectIgnoreDifferences=true]`.)
   Alternative: delete `replicas: 2` from `deploy/deployment.yaml` and push.
4. **Verify.** `argocd app get quote-api` is `Synced`, `kubectl -n quotes get deploy` stays at 4/4 and
   `metadata.generation` stops growing. Then run `check` in the game.

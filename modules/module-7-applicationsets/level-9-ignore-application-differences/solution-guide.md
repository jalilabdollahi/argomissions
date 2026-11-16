# Walkthrough — The Set Reverts My Change

1. **Reproduce the revert.**
   ```bash
   argocd app set feedhub-prod --revision hotfix-1.8.1
   sleep 3; argocd app get feedhub-prod | grep -i 'target'      # main again
   kubectl -n argocd get application feedhub-prod -o jsonpath='{.metadata.ownerReferences[0].kind}'   # ApplicationSet
   ```
2. **Understand.** The generated Application is not yours: the ApplicationSet controller re-renders its template
   and overwrites the Application's `spec` when it differs, which includes the change you just made.
3. **Option A: tell the controller to ignore the field.** In `feedhub-appset.yaml`:
   ```yaml
   spec:
     ignoreApplicationDifferences:
     - jsonPointers:
       - /spec/source/targetRevision
   ```
   ```bash
   kubectl apply -f feedhub-appset.yaml
   argocd app set feedhub-prod --revision hotfix-1.8.1
   argocd app wait feedhub-prod --health
   ```
   **Option B: make the template say it.** Add `revision: main` to the dev and stage elements and
   `revision: hotfix-1.8.1` to prod, and use `targetRevision: '{{.revision}}'` in the template.
4. **Verify.** After 10 seconds `argocd app get feedhub-prod` still tracks `hotfix-1.8.1`, is Synced, and
   `curl feedhub.feedhub-prod` (from a pod) answers `feedhub v1.8.1-hotfix`. `dev` and `stage` stay on `main`.
   Then run `check` in the game.

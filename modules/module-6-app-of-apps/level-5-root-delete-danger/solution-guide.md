# Walkthrough — The Day The Root Was Deleted

1. **Find the accident.**
   ```bash
   argocd app list                       # inventory-root and stock-sync; stock-api is gone
   cd inventory-gitops && git log --stat -3   # "cleanup: drop unused manifests" deleted apps/api.yaml
   kubectl -n inventory-stock get all    # nothing: the child's finalizer cascaded to the workloads
   ```
2. **Bring the service back from history** with a new commit (do not rewrite `main`):
   ```bash
   git show HEAD~1:apps/api.yaml > apps/api.yaml      # or: git revert HEAD
   ```
3. **Protect every child** (`apps/api.yaml` and `apps/sync.yaml`):
   ```yaml
   metadata:
     name: stock-api
     namespace: argocd
     annotations:
       argocd.argoproj.io/sync-options: Prune=false,Delete=false
   ```
   `Prune=false`: the root keeps the child even when its manifest disappears (the root just shows `OutOfSync`,
   "ignored (no prune)"). `Delete=false`: the child survives when the root Application is deleted.
4. **Push and let the root sync.**
   ```bash
   git add -A && git commit -m "restore stock-api; protect children" && git push
   argocd app get inventory-root --refresh
   ```
5. **Verify.** `argocd app list` shows root and both children Synced/Healthy; `kubectl -n argocd get application stock-api
   -o jsonpath='{.metadata.annotations}'` shows the sync options; `stock-sync` kept its pods.

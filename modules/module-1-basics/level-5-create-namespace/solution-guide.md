# Walkthrough — No Room At The Inn

1. **See the failure.**
   ```bash
   argocd app get ledger
   kubectl get namespace ledger        # NotFound
   ```
   The last operation failed: `one or more objects failed to apply, reason: namespaces "ledger" not found`.
   The Deployment and Service are both listed as `SyncFailed`.
2. **Decide how to fix it.** `kubectl create namespace ledger` would work once, but the Application would
   break again on every new cluster. The durable fix is a sync option on the Application.
3. **Set the option.**
   ```bash
   argocd app set ledger --sync-option CreateNamespace=true
   ```
   (UI: **App Details** → **Edit** → Sync Options → *Auto-Create Namespace*.)
4. **Sync.**
   ```bash
   argocd app sync ledger
   argocd app wait ledger --health
   ```
5. **Verify.**
   ```bash
   argocd app get ledger -o yaml | grep -A3 syncOptions
   kubectl get namespace ledger
   kubectl -n ledger run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s ledger
   ```
   Then run `check` in the game.

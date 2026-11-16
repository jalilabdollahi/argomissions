# Walkthrough — The Hotfix That Must Survive

1. **See the drift.**
   ```bash
   argocd app get checkout           # Sync Status: OutOfSync, Deployment checkout OutOfSync
   argocd app diff checkout          # replicas: 3 (live)  vs  replicas: 1 (Git)
   kubectl -n checkout get deploy checkout    # READY 3/3
   ```
2. **Do not press Sync yet.** A sync applies Git: the Deployment would go back to 1 replica.
3. **Write the hotfix down in Git.**
   ```bash
   cd checkout
   sed -i 's/^  replicas: 1$/  replicas: 3/' deploy/deployment.yaml
   git commit -am "checkout: 3 replicas (load spike capacity)" && git push
   ```
4. **Sync to the new head.**
   ```bash
   argocd app sync checkout
   argocd app wait checkout --health
   ```
   The live Deployment already has 3 replicas, so nothing changes in the cluster: the diff just disappears.
5. **Verify** `argocd app get checkout` (Synced, Healthy, revision = head of main) and
   `kubectl -n checkout get deploy checkout` (3/3), then run `check` in the game.

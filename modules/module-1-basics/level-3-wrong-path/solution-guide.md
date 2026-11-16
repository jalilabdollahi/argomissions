# Walkthrough — The Moved Manifests

1. **Read the error.**
   ```bash
   argocd app get catalog
   ```
   `ComparisonError: ... k8s: app path does not exist`. The Application asks for folder `k8s`.
2. **Look at the repo.**
   ```bash
   cd catalog
   git log --stat --oneline
   ls
   ```
   The newest commit, "restructure: move manifests to deploy/catalog", renamed `k8s/*.yaml` to
   `deploy/catalog/*.yaml`. The Application was never told.
3. **Update the Application, not the repo.**
   ```bash
   argocd app set catalog --path deploy/catalog
   ```
   (UI: **App Details** → **Edit** → Path. Or `kubectl -n argocd edit application catalog`.)
4. **Sync.**
   ```bash
   argocd app sync catalog
   argocd app wait catalog --health
   ```
5. **Verify.**
   ```bash
   argocd app get catalog     # Synced, Healthy, path deploy/catalog
   kubectl -n catalog run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s catalog
   ```
   Then run `check` in the game.

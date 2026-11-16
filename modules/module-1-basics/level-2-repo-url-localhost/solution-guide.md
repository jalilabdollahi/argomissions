# Walkthrough — Works On My Laptop

1. **Read the error.**
   ```bash
   argocd app get orders
   ```
   The condition is a `ComparisonError`: `failed to list refs: Get "http://localhost:3300/platform/orders.git/...":
   dial tcp [::1]:3300: connect: connection refused`. The repo-server could not even list the branches.
2. **Understand whose `localhost` it is.** The repo-server runs as a pod in the cluster. `localhost:3300` there is
   the pod itself, where nothing listens. Gitea is reachable inside the cluster as a Service:
   `http://gitea.gitea.svc.cluster.local:3000` (service `gitea`, namespace `gitea`, port 3000).
3. **Change the repo URL.**
   ```bash
   argocd app set orders --repo http://gitea.gitea.svc.cluster.local:3000/platform/orders.git
   ```
   (UI: Application → **App Details** → **Edit** → Repository URL. Or `kubectl -n argocd edit application orders`.)
4. **Sync.**
   ```bash
   argocd app sync orders
   argocd app wait orders --health
   ```
5. **Verify.**
   ```bash
   argocd app get orders       # Synced, Healthy
   kubectl -n orders run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s orders
   ```
   Then run `check` in the game.

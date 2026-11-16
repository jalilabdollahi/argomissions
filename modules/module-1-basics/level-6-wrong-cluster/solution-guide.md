# Walkthrough — Cluster Not Found

1. **Read the condition.**
   ```bash
   argocd app get telemetry
   ```
   `InvalidSpecError: error getting cluster by server "https://kubernetes.default.svc.cluster.local" ... not found`.
2. **List what Argo CD knows.**
   ```bash
   argocd cluster list
   ```
   There is one cluster: server `https://kubernetes.default.svc`, name `in-cluster`. The Application's URL is a
   different string, so it is not a registered cluster.
3. **Fix the destination.**
   ```bash
   argocd app set telemetry --dest-server https://kubernetes.default.svc
   ```
   (UI: **App Details** → **Edit** → Cluster URL. Or set `destination.name: in-cluster` instead of `server`.)
4. **Sync.**
   ```bash
   argocd app sync telemetry
   argocd app wait telemetry --health
   ```
5. **Verify.**
   ```bash
   argocd app get telemetry       # Synced, Healthy, destination in-cluster
   kubectl -n telemetry run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s telemetry
   ```
   Then run `check` in the game.

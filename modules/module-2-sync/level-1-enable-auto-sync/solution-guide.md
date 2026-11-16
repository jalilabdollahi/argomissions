# Walkthrough — Deploy On Merge

1. **Look at the Application.**
   ```bash
   argocd app get metrics-gw
   ```
   `Sync Policy: Manual`, `Sync Status: OutOfSync from main (<sha>)`. Git is ahead of the cluster.
   `git -C metrics-gw log --oneline` shows the three releases that were never deployed.
   `argocd app diff metrics-gw` shows the image text moving from `v1.0` to `v1.3`.
2. **Do not just sync.** `argocd app sync metrics-gw` fixes today only: the next merge is stuck again.
3. **Turn on automated sync.**
   ```bash
   argocd app set metrics-gw --sync-policy automated
   ```
   (UI: Application → **Details** → **Sync Policy** → **Enable Auto-Sync**. YAML: `spec.syncPolicy.automated: {}`.)
4. **Watch.** Within a few seconds Argo CD starts a sync by itself (`argocd app get metrics-gw` shows
   `Sync Policy: Automated`, `Synced to main`).
5. **Verify.**
   ```bash
   argocd app get metrics-gw
   kubectl -n metrics run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s metrics-gw
   ```
   The answer is `metrics-gw v1.3`. Then run `check` in the game.

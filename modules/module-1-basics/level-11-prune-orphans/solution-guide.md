# Walkthrough — The Ghost Worker

1. **Inspect the Application.**
   ```bash
   argocd app get media
   ```
   `Sync Status: OutOfSync`; the `legacy-worker` Deployment is listed as `OutOfSync` with the note
   `requires pruning`, and its message reads `ignored (requires pruning)`; a plain `argocd app sync` even ends with `1 resources require pruning`.
2. **Confirm what Git says.**
   ```bash
   git -C media log --stat -3     # "retire legacy worker" deleted deploy/legacy-worker.yaml
   argocd app diff media          # shows the live legacy-worker with nothing on the Git side
   ```
3. **Sync with prune.**
   ```bash
   argocd app sync media --prune
   ```
   (UI: Sync → tick **Prune**.) Only `legacy-worker` is deleted; `media-web` is unchanged.
4. **Verify.**
   ```bash
   argocd app get media                       # Synced, Healthy
   kubectl -n media-prod get deploy           # only media-web
   ```
   Then run `check` in the game.

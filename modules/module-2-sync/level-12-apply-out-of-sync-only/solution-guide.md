# Walkthrough — The Slow Sync

1. **Look at the state.**
   ```bash
   argocd app diff region-configs        # only edge-banner and region-eu-west differ
   kubectl -n regions get cm visit-counter -o jsonpath='{.data.count}'    # 4821
   ```
   The counter does not show in the diff: the Application ignores `/data/count`. That hides the difference from the
   comparison, not from the apply.
2. **Do not sync yet.** A normal sync applies all 11 resources, including `visit-counter` with Git's `count: "0"`.
3. **Restrict syncs to out-of-sync resources, then sync.**
   ```bash
   argocd app set region-configs --sync-option ApplyOutOfSyncOnly=true
   argocd app sync region-configs
   argocd app wait region-configs --health
   ```
   (UI: App Details → Edit → Sync Options → *Apply Out of Sync Only*, then Sync.) The sync output marks the in-sync
   objects as skipped, only `edge-banner` and `region-eu-west` are applied.
4. **Verify.**
   ```bash
   kubectl -n regions get cm visit-counter -o jsonpath='{.data.count}'    # 4821
   kubectl -n regions run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s edge-banner   # edge-banner r42
   ```
   Then run `check` in the game.

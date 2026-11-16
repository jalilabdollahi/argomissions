# Walkthrough — The Commit Nobody Shipped

1. **Look at the Application.**
   ```bash
   argocd app get search-api      # Sync Status: OutOfSync
   argocd app history search-api  # one deployment, the old commit
   ```
2. **Read the diff before touching anything.**
   ```bash
   argocd app diff search-api
   ```
   The only change: the container args go from `-text=search-api v2.2` to `-text=search-api v2.3`.
   (`git log` in your clone shows the commit "release v2.3".)
3. **Sync.** The Application has no `syncPolicy.automated`, so a merge is only a proposal until someone syncs:
   ```bash
   argocd app sync search-api
   argocd app wait search-api --health
   ```
   (UI: open the app, check the diff, press **Sync**.)
4. **Verify.**
   ```bash
   argocd app history search-api    # a second entry: the new commit
   kubectl -n search run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s search-api
   ```
   Then run `check` in the game.

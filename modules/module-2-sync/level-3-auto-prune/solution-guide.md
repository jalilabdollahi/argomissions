# Walkthrough — Automated, But Not Tidy

1. **Look.**
   ```bash
   argocd app get gallery-web
   ```
   `Sync Policy: Automated`, `Sync Status: OutOfSync`, and the resource table shows Service `gallery-classic`
   as `OutOfSync` while everything else is `Synced`. `argocd app diff gallery-web` shows the whole Service
   as a deletion (every line prefixed `<`). `git -C gallery-web log --stat` shows the manifest was deleted.
2. **Understand.** The live Service exists but Git no longer describes it: Argo CD calls it *requires pruning*.
   Automated sync does not start a sync that would only delete things, and a sync would not delete anything
   unless pruning is allowed.
3. **Allow pruning in the policy.**
   ```bash
   argocd app set gallery-web --auto-prune
   ```
   (UI: Details → Sync Policy → enable **Prune Resources**; YAML: `syncPolicy.automated.prune: true`.)
4. **Watch.** Argo CD syncs by itself, deletes `gallery-classic`, and the app becomes `Synced`.
5. **Verify.**
   ```bash
   kubectl -n gallery get svc          # only gallery-web is left
   argocd app get gallery-web
   ```
   Then run `check` in the game.

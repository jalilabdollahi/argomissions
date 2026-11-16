# Walkthrough — Undo Without Rewriting History

1. **See what changed and what runs.**
   ```bash
   argocd app get reports                  # Synced, Degraded
   argocd app history reports              # two deployed revisions
   git -C reports log --oneline            # "tune worker flags" on top of "report-worker v1.0"
   kubectl -n reports get pods             # CrashLoopBackOff
   kubectl -n reports logs deploy/report-worker    # flag provided but not defined: -workers
   ```
2. **(Optional) stop the bleeding.**
   ```bash
   argocd app rollback reports 0
   ```
   The old release runs again, but the Application is now OutOfSync: Git still says "tuned".
3. **Undo the commit in Git, without rewriting history.**
   ```bash
   cd reports
   git revert --no-edit HEAD
   git push
   ```
   `git revert` adds a new commit whose diff is the exact opposite of the bad one.
4. **Sync to the new head.**
   ```bash
   argocd app sync reports
   argocd app wait reports --health
   ```
5. **Verify**: `argocd app get reports` (Synced to the revert commit, Healthy),
   `git -C reports log --oneline` (three commits, the bad one still there), then run `check` in the game.

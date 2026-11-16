# Walkthrough — Frozen Friday

1. **See why the sync is refused.**
   ```bash
   argocd app sync statement-api          # PermissionDenied: cannot sync: blocked by sync window
   argocd app get statement-api           # SyncWindow: Sync Denied / Assigned Windows: deny:* * * * *:24h
   argocd proj windows list billing-core  # ID 0, deny, * * * * *, 24h, ManualSync Disabled
   ```
2. **Decide what to change.** Deleting the window lifts the whole freeze (automated syncs, other applications).
   The freeze should stop *automated* deployments, but an approved human must be able to push a fix.
   A deny window has a `manualSync` flag for exactly that.
   ```bash
   argocd proj windows enable-manual-sync billing-core 0
   ```
   YAML equivalent: `manualSync: true` on the window in `spec.syncWindows` of the AppProject.
3. **Sync by hand.** Automated sync stays blocked by the window, so start it yourself:
   ```bash
   argocd app sync statement-api
   argocd app wait statement-api --health
   ```
4. **Verify.** `argocd app get statement-api` is Synced at the head, the SyncWindow line no longer says
   `Sync Denied`, and `argocd proj windows list billing-core` still shows the deny window.

Alternative: narrow the window to the real freeze hours (delete it and add one with a proper
`--schedule`/`--duration`); when it is not active, Argo CD syncs the fix on its own.

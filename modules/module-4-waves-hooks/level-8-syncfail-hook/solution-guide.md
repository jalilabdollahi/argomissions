# Walkthrough — Clean Up On Failure

1. **See what the failed sync ran.**
   ```bash
   argocd app get booking-portal --show-operation
   # ConfigMap maintenance-flag  PreSync  Succeeded
   # Job schema-gate             PreSync  Failed   (Job has reached the specified backoff limit)
   kubectl -n bookings get configmap maintenance-flag      # still there
   ```
   `exit-maintenance` never ran in that sync.
2. **Read the cleanup Job.**
   ```bash
   grep -n argocd booking-portal/deploy/exit-maintenance.yaml
   # argocd.argoproj.io/hook: PostSync
   ```
   PostSync runs after a successful sync only. When the PreSync gate fails, the operation jumps straight to the
   `SyncFail` phase, skipping Sync and PostSync.
3. **Run the cleanup on failure too.** One Job, two phases:
   ```bash
   cd booking-portal
   sed -i.bak 's/hook: PostSync/hook: PostSync,SyncFail/' deploy/exit-maintenance.yaml && rm deploy/exit-maintenance.yaml.bak
   git commit -am "exit-maintenance: also run when the sync fails" && git push
   ```
   (A separate Job with `hook: SyncFail` works as well.)
4. **Sync the new head.** It fails at the schema gate again, as designed, and the SyncFail hook runs:
   ```bash
   argocd app sync booking-portal
   argocd app get booking-portal --show-operation     # exit-maintenance, HOOK SyncFail, Succeeded
   kubectl -n bookings get configmap maintenance-flag # NotFound
   ```

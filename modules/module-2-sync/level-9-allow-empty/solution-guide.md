# Walkthrough — Nothing Left To Deploy

1. **See why nothing happens.**
   ```bash
   argocd app get nightly-etl
   kubectl -n etl get deploy,svc,cm
   git -C nightly-etl log --stat -2
   ```
   The app is `OutOfSync` (three resources are no longer in Git, so they need pruning) and carries
   `SyncError: Skipping sync attempt to <commit>: auto-sync will wipe out all resources`. The last commit removed
   every manifest from `deploy/`.
2. **Do not revert.** The workloads are supposed to leave this repo.
3. **Tell the automated policy that an empty application is intended.**
   ```bash
   argocd app set nightly-etl --sync-policy automated --auto-prune --self-heal --allow-empty
   ```
   (YAML: `spec.syncPolicy.automated.allowEmpty: true`; UI: App Details → Sync Policy → *Allow Empty*.)
   The next reconcile syncs: the three objects are pruned.
4. **Alternative:** a human sync is allowed to empty an application:
   ```bash
   argocd app sync nightly-etl --prune
   ```
   Fine for a one-off, but the Application stays one commit away from the same situation.
5. **Verify.**
   ```bash
   argocd app get nightly-etl                 # Synced, no conditions
   kubectl -n etl get deploy,svc,cm           # only kube-root-ca.crt
   ```
   Then run `check` in the game.

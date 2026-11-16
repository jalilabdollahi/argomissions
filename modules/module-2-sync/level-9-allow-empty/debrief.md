# Nothing Left To Deploy

## What broke
A commit removed every manifest from the Application's folder. The Application has `automated.prune: true`, so one would
expect Argo CD to delete the leftovers. It did not: it set the condition `SyncError: Skipping sync attempt to <commit>:
auto-sync will wipe out all resources` and left the Deployment, Service and ConfigMap running, OutOfSync, forever.

## Why Argo CD behaves this way
An Application whose desired state is *no resources at all* is far more often a mistake than a decision: a wrong
`path`, a failed manifest generation that produced nothing, a bad merge. Pruning everything on an automated trigger would
delete a whole workload without a human in the loop, so automated sync refuses unless the policy says
`allowEmpty: true`. The guard applies to automated syncs only; a person pressing Sync with prune is, by definition, a
human decision. Note the app does not turn `Degraded` or `Failed`: it is simply waiting, which is why this looks like
"auto-sync stopped working".

(The folder still exists because of its README: Git does not store empty directories, and a missing path is a different
error, `app path does not exist`.)

## The fix
Set `spec.syncPolicy.automated.allowEmpty: true` (CLI `--allow-empty`). Auto-sync then runs, prunes the three objects and the
Application is Synced with an empty resource list. Syncing once manually with `--prune` also works but leaves the guard in
place for the next time.

## In real life
This shows up when a service migrates to another repo or cluster, when a Helm values flag switches a whole chart off, or
when a repo is restructured. Decide deliberately: keep `allowEmpty` off for long-lived apps (the guard saved someone's
production once), and enable it only for the commit that retires an app, or delete the Application with its resources
cascade instead. Remember that `prune` also needs the `Prune=false` escape hatch if some objects must survive.

## Commands worth remembering
```bash
argocd app get APP                          # conditions and OutOfSync resources
argocd app set APP --allow-empty --sync-policy automated --auto-prune
argocd app sync APP --prune                 # manual prune (not blocked by the empty guard)
argocd app diff APP                         # what would be deleted
```

## Common mistakes
- Reverting the commit so that "something" exists: the workloads were meant to go.
- Deleting the leftovers with `kubectl`: the app flips to Synced but no sync ran at the new commit, and the guard is still
  there for the next retirement.
- Enabling `prune` and expecting it to cover this: prune does not override the empty-application guard.

## Argo CD 2.x vs 3.x
The guard and the message are unchanged between 2.x and 3.x. The condition is reported as `SyncError` on the Application
and no operation is started, so `argocd app history` shows nothing new.

# Debrief — Remove The Old Last

## What broke
Nothing is broken yet: the release renames the Service and Deployment, and the default sync would delete the old
`relay` Service in the same wave in which it creates `relay-gateway`. Clients using `relay` lose the service while
the new pods are still starting (here the new readiness probe waits 8 seconds), an outage window that a green sync
status hides completely.

## Why Argo CD behaves this way
Argo CD applies a sync in phases and waves. Resources that disappeared from Git are pruned as tasks of their own wave
(wave 0 unless the live object says otherwise), not "after everything else". The option `PruneLast=true` moves all
prune tasks to a final wave after every other resource and hook of the sync has been applied and has become Healthy.
The old Service therefore stays up until the new one is ready, and clients can be moved over safely.
It can be set for the whole Application (`syncPolicy.syncOptions`) or per resource with the annotation
`argocd.argoproj.io/sync-options: PruneLast=true` on the object that will be pruned. Manual syncs only prune when you
ask for it (`--prune`, the Prune checkbox) or when automated sync has `prune: true`.

## The fix
Add `PruneLast=true` to the Application's sync options (keep `CreateNamespace=true`), then sync with pruning. The
`handover-check` hook, which runs after wave 0, sees both Services answering; afterwards the old Deployment and Service
are removed.

## In real life
Renames, selector changes and "replace one component with another" are the classic reasons for an outage during an
otherwise healthy GitOps sync. PruneLast, together with waves for the new objects, gives you a make-before-break
rollout. Plan the client cut-over in a hook or a separate release when "both names answer" must hold longer than one sync.

## Commands worth remembering
- `argocd app diff APP` — what would be created and what would be pruned.
- `argocd app set APP --sync-option PruneLast=true` — note: it replaces the whole option list.
- `argocd app sync APP --prune` — manual sync that also deletes what left Git.
- `kubectl -n NS logs job/NAME` — evidence left by a hook with `BeforeHookCreation`.

## Common mistakes
- Syncing with `--prune` first and thinking about ordering later: the old objects are already gone; undo the rename in
  Git, sync, and redo it.
- `argocd app set --sync-option PruneLast=true` alone: it drops `CreateNamespace=true` from the list.
- Setting the option but never syncing: the Application stays OutOfSync and the old objects keep running.

## Argo CD 2.x vs 3.x
`PruneLast` behaves the same. In 3.x, manual syncs from the CLI and UI copy `syncOptions` of the Application into the
operation, while a hand-written `operation` patch does not (use the CLI, the UI, or an `operation` that lists them).

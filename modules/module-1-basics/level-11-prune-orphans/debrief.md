# The Ghost Worker

## What broke
The commit "retire legacy worker" deleted `deploy/legacy-worker.yaml` from Git, and the Application was synced.
But the worker kept running in `media-prod` and the Application stayed `OutOfSync`. Nothing was misconfigured in
Git: Argo CD simply never deleted the object.

## Why Argo CD behaves this way
Deleting live resources is the most dangerous thing a sync can do, so it is opt-in. A normal sync creates and
updates objects; objects that Argo CD tracks for the Application but that are no longer in Git are marked
*requires pruning*. They show as `OutOfSync`, the sync result says `ignored (requires pruning)` (the CLI exits with `1 resources require pruning`), and
they stay until you sync with **prune** (`argocd app sync --prune`, the Prune checkbox in the UI, the sync option
`Prune=true`, or `syncPolicy.automated.prune: true`).

Argo CD only prunes objects that carry its tracking annotation for *this* Application, so a prune cannot touch
things it never deployed. The Application stays OutOfSync until the orphan is gone, which is the signal that
Git and the cluster disagree.

## The fix
Sync with prune. `legacy-worker` is deleted, `media-web` and its Service are left alone, and the Application is
`Synced` at the head of `main`. Deleting the Deployment with `kubectl` also ends the drift (Git already wants it
gone), but it bypasses the review trail and does not teach the Application how to clean up next time.

## In real life
Orphans pile up quietly: renamed Deployments, removed CronJobs, old Ingresses that still route traffic. They run
up cost and sometimes keep serving. Teams turn on automated prune for stateless apps and keep manual prune (or
`Prune=false` annotations, `PruneLast=true`) for resources where deletion is risky, such as PVCs.

## Commands worth remembering
```bash
argocd app get media                      # look for "requires pruning" / OutOfSync rows
argocd app diff media
argocd app sync media --prune
argocd app sync media --dry-run --prune   # preview
argocd app set media --sync-policy automated --auto-prune
```

## Common mistakes
- Syncing again without prune and expecting the orphan to disappear.
- Deleting the whole Application or namespace to "start clean": that recreates `media-web` too.
- Turning on automated prune without looking at what is about to be removed.

## Argo CD 2.x vs 3.x
Prune behaviour is unchanged. In 3.x tracking uses annotations, so only objects with
`argocd.argoproj.io/tracking-id` for this Application are candidates for pruning.

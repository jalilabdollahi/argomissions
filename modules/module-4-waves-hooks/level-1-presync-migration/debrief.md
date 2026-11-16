# Migrate Before You Deploy

## What broke
Nothing was invalid: every manifest was fine and the sync would have succeeded. The problem was *time*.
The migration Job had no hook annotation and no wave, so Argo CD treated it like the Deployment: apply both,
then watch health. The new pods started serving while the schema was still being migrated, and for about 12
seconds the API ran against a database it did not understand.

## Why Argo CD behaves this way
A sync is not one big `kubectl apply`. It has **phases**: `PreSync` → `Sync` → `PostSync` (plus `SyncFail`).
Resources without a hook annotation live in the `Sync` phase. Inside a phase, resources are grouped into
**waves** (`argocd.argoproj.io/sync-wave`, default 0, lowest first), and within one wave Argo CD applies them
in a fixed kind order (Namespace, ConfigMap, Service, Deployment, Job ...).

Argo CD only moves to the next wave or phase when everything in the current one is **Healthy**. For a Job,
Healthy means *completed successfully*. That is what makes a migration safe: a `PreSync` hook Job must finish
before the first manifest of the Sync phase is touched, and if it fails the sync stops, the old version keeps
running, and the Application shows the failed hook. A hook is also re-created on each sync, which is what you
want for a one-shot task.

## The fix
Annotate the Job with `argocd.argoproj.io/hook: PreSync` (Git change, then sync). Giving the Job a lower
sync wave than the Deployment also works for ordering, but a hook is the idiomatic tool for "run this task
at a point of the sync" and is shown separately in `argocd app get`.

## In real life
Database migrations, schema checks, cache warm-ups and "block the rollout unless X" gates are PreSync hooks in
most Argo CD installations. The classic incident is the staging one in this mission: migration and application
rolled out together, usually discovered only under load. Keep migrations backward compatible when you can
(expand/contract), because a PreSync hook also runs for rollbacks and for every sync, not only for new releases.

## Commands worth remembering
```bash
argocd app get NAME                  # resources with their sync phase and hook phase
argocd app diff NAME
argocd app sync NAME --refresh
kubectl -n NS get job,rs             # creation and completion times show the real order
kubectl -n NS logs job/NAME
```

## Common mistakes
- Syncing and hoping: with a plain Job the sync "succeeds" and the race is invisible until production.
- Running the migration by hand before the sync: it works once, and the next release has the same race because
  Git does not say that the migration comes first.
- Forgetting that a hook that never completes blocks the sync forever: give migrations a `backoffLimit` and a
  `activeDeadlineSeconds`.

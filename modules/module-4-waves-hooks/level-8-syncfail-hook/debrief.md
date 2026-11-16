# Debrief — Clean Up On Failure

## What broke
The deployment process raises a maintenance banner in a PreSync hook and lowers it in a PostSync Job. Release v5.2 failed
at its PreSync `schema-gate` hook, so the operation never reached PostSync, and nobody lowered the banner. The site stayed
read-only until a human noticed. The cleanup existed in Git, but in a phase that only runs on the happy path.

## Why Argo CD behaves this way
A sync operation moves through phases: PreSync, Sync (in waves), PostSync. If any task fails (a hook that fails, a
resource that cannot be applied, a resource that never turns Healthy and times out), Argo CD stops running the remaining
phases and runs the hooks annotated `argocd.argoproj.io/hook: SyncFail` instead. PostSync hooks are explicitly "after a
successful sync". The `hook` annotation accepts a comma-separated list, so one Job can serve several phases
(`PostSync,SyncFail`). The operation still ends Failed: SyncFail hooks clean up, they do not turn a failure into a success.
Observed on Argo CD 3.6.1: the `SyncFail` Job appears in the sync result with hookType SyncFail and its own phase.

## The fix
Add `SyncFail` to the cleanup hook (or create a second Job in that phase), push, and sync. The release still fails at the
gate, the SyncFail hook deletes `maintenance-flag`, and the site comes back.

## In real life
Anything a pipeline "acquires" before a deploy (maintenance banners, feature freezes, locks, scaled-down consumers,
paused alerts) must be released on the failure path too. SyncFail hooks are the Argo CD way: notifications, lock release,
rollback triggers. Keep them idempotent and tolerant (here a 404 on the delete is fine), and give them the RBAC they need
before they are needed: a SyncFail Job that is itself forbidden fails silently when you need it most.

## Commands worth remembering
- `argocd app get APP --show-operation` — phase, message and the hooks that ran, with their HOOK type.
- `kubectl -n NS get jobs,pods` — hook Jobs and their logs (`kubectl logs job/NAME`).
- `argocd app sync APP` — runs the whole operation again, hooks included; it exits non-zero when the sync fails.

## Common mistakes
- Deleting the ConfigMap by hand: the banner goes away once, and the next failed release leaves it up again.
- Moving the Job to another happy-path phase (Sync, PostSync): none of them run after a failure.
- "Fixing" the sync by removing the schema gate: the release was blocked on purpose, and a failure handler is about
  surviving failure, not avoiding it.

## Argo CD 2.x vs 3.x
SyncFail semantics are the same in 3.x. PostDelete hooks (added in 2.10) are a separate phase for Application deletion.

# Debrief — The Hook That Never Ran

## What broke
The `reindex-tickets` Job carried the annotation `argocd.argoproj.io/hook: PreSynk`. The release synced
"successfully", but the Job never ran: it was not applied, not listed in the Application, and nothing complained.
Search served a stale index because the step that was supposed to guard the rollout did not exist as far as
Argo CD was concerned.

## Why Argo CD behaves this way
A manifest with the `argocd.argoproj.io/hook` annotation is a *hook*, not a regular resource. Hooks are excluded
from the normal "desired state" and are only created at the moment their phase runs (PreSync, Sync, PostSync,
SyncFail, PostDelete). When the annotation value is not one of those phases, Argo CD still treats the object as
a hook, but there is no phase in which to run it, so it is skipped without a warning. Observed on Argo CD
3.6.1: no Job is created, it does not show up in `argocd app get`, the sync ends Succeeded.
Because hooks live outside the comparison, fixing the annotation does not make the Application OutOfSync: you must
start a sync of the new head for the hook to execute.

## The fix
Correct `PreSynk` to `PreSync` in Git, push, refresh, and run a sync. The sync result then lists the Job with
HOOK `PreSync`, phase Succeeded, and the Deployment is only touched afterwards.

## In real life
A typo in an annotation is invisible in code review and never produces an error. The classic victims are database
migrations, cache warmers and smoke tests, which "pass" because they simply do not run. After adding a hook,
always look at the sync result of the next sync (`argocd app get`, the HOOK column) and at the Job's logs.

## Commands worth remembering
- `argocd app get APP` — the HOOK column shows which resources are hooks and of which phase.
- `argocd app history APP` and `argocd app get APP --show-operation` — what the last sync actually ran.
- `kubectl -n NS get jobs,pods` — hook Jobs leave evidence unless a delete policy removes them.
- `argocd app sync APP` — hooks only run inside a sync, even when the app already says Synced.

## Common mistakes
- Running the Job by hand with `kubectl`: the index is rebuilt once, but the next release has the same bug.
- Fixing the annotation and waiting: the Application stays Synced, hooks do not run on their own.
- Moving the Job to a plain resource (removing the annotation): it then races the Deployment instead of
  finishing before it.

## Argo CD 2.x vs 3.x
Unknown hook values were handled the same way in 2.x. What changed in 3.x is annotation-based resource tracking
by default, which does not affect this lesson.

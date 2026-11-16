# Job Already Exists

## What broke
The migration Job is a PreSync hook with `hook-delete-policy: HookFailed`. Someone chose it to keep successful
runs around for their logs. Release v1 ran the Job and left it in the cluster. Release v2 changed the Job's
command; Argo CD found the old Job, tried to patch it, and Kubernetes refused: a Job's pod template is
immutable (`field is immutable`). The sync stopped at the hook, v2 never rolled out.

## Why Argo CD behaves this way
Hooks are resources that Argo CD creates at a point of the sync, but they are not "owned" like normal objects.
The **hook delete policy** decides when the previous run is removed:

* `BeforeHookCreation`: delete the old one right before creating the new one (the default when you set no
  policy at all);
* `HookSucceeded`: delete it as soon as it succeeded;
* `HookFailed`: delete it only if it failed.

Once you name a policy yourself, only that policy applies. With `HookFailed` a *successful* run is never
removed, so the next sync finds a live Job with the same name and tries to update it instead of re-running it.
If nothing about the Job changed, the patch is a no-op and the hook is "done" without running again (a silent
skip); if the pod template changed, Kubernetes rejects the patch. A failed run was cleaned up, so a plain retry
passes once, which makes the problem look like flakiness.

## The fix
Use a policy that removes the previous run: `BeforeHookCreation` (the usual choice, the last run stays visible
until the next one) or `HookSucceeded`. Or set no policy at all. It is a one-line change in Git.

## In real life
Every team that runs migrations or batch tasks from Argo CD meets this once, often as "every second release
fails" or "the migration did not run for this release". Prefer `BeforeHookCreation`; add `HookSucceeded` too if
you do not want Completed Jobs and pods piling up. If you need run history, collect logs elsewhere. Putting the
release into the Job name (generateName or a kustomize suffix) is another way out for non-hook Jobs.

## Commands worth remembering
```bash
argocd app get NAME                    # failed hook and the Kubernetes error
kubectl -n NS get job,pod
kubectl -n NS logs job/NAME
argocd app history NAME
```

## Argo CD 2.x vs 3.x
The error text of the older docs, `jobs.batch "X" already exists`, does not appear here: Argo CD 3.x finds the
existing hook and patches it, so the visible failure is the immutable pod template (or nothing at all when the
Job did not change).

## Common mistakes
- Syncing again: the failed run was deleted, so it passes once, and the next change to the migration fails again.
- Deleting the Job with `kubectl` before each release: a manual step that the pipeline will forget.
- Setting `HookFailed` thinking it means "clean up after the hook": it means *only* when it failed.

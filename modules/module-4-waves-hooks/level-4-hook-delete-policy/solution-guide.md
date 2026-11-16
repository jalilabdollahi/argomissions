# Walkthrough — Job Already Exists

1. **Read the failure.**
   ```bash
   argocd app get helpdesk-api
   ```
   The operation `Failed` at the PreSync hook: `Job.batch "helpdesk-db-migrate" is invalid: spec.template: ...
   field is immutable`. Release v2 changed the Job's command, and Argo CD tried to patch the Job that release
   v1 left behind. A Job's pod template is immutable.
2. **Look at the hook definition.**
   ```bash
   cat helpdesk-api/deploy/migrate-job.yaml
   ```
   `hook: PreSync` and `hook-delete-policy: HookFailed`. With `HookFailed` Argo CD deletes the Job only if it
   failed; a successful run stays. (Without any policy, or with `BeforeHookCreation`, Argo CD deletes the old run
   right before it creates the new one.)
3. **Fix the policy in Git.**
   ```yaml
   argocd.argoproj.io/hook: PreSync
   argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
   ```
   (`HookSucceeded` also works: the Job disappears after a successful run, so nothing is left to collide with.)
4. **Push and sync.**
   ```bash
   cd helpdesk-api && git commit -am "migration hook: BeforeHookCreation" && git push
   argocd app sync helpdesk-api --refresh
   argocd app wait helpdesk-api --health
   ```
5. **Verify.** `argocd app get helpdesk-api` lists the Job as a PreSync hook, `Succeeded`; the service answers
   `helpdesk-api v2`. Run `check` in the game.

Note: simply syncing again also goes green (the failed hook run was deleted by `HookFailed`), but Git still
leaves a successful run behind, so the next change to the Job fails again. That is what the mission checks.

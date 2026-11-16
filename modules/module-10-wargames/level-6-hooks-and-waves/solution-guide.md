# Runbook: release v7 of shiftboard

1. **Read the state.**
   `argocd app get shiftboard --show-operation` shows the failed PreSync hook `rota-migrate`;
   `kubectl -n shiftboard get events` and `argocd app diff shiftboard` show what v7 changed;
   `argocd app list` shows `rota-crds` OutOfSync. `git show HEAD --stat` lists the files of release v7.
2. **Fault 1 - hook delete policy.** `deploy/migrate-job.yaml` has `hook-delete-policy: HookFailed`: a *successful*
   run stays in the cluster, and v7 changes its pod template (immutable). The failed second attempt was cleaned
   up by the same policy, which is why the error changed. Use `BeforeHookCreation`.
3. **Fault 2 - RBAC after the migration.** The new migration PATCHes a ConfigMap, so v7 adds the verb `patch`
   to Role `rota-migrator`; but the Role is a normal resource and PreSync hooks run before the sync phase
   (`kubectl -n shiftboard logs job/rota-migrate` showed `configmaps "schema-version" is forbidden`... when it ran).
   Make ServiceAccount, Role and RoleBinding PreSync hooks with `sync-wave: "-1"` and
   `hook-delete-policy: BeforeHookCreation`, so they are applied before the Job (wave 0).
   (Equivalent: leave the RBAC alone, make the Job a `Sync` hook in a later wave and move the Deployment after it.)
4. **Fault 3 - the CRD lags.** `deploy/weekend-policy.yaml` has `restDays`, `crds/shift-policy.yaml` gained it in
   the same release, but `rota-crds` is manual and nobody synced it: the cluster's CRD schema prunes the unknown field,
   so `ShiftPolicy weekend` is applied without `restDays` and stays OutOfSync after every sync (`argocd app diff shiftboard`
   shows `restDays: 2` missing). `argocd app set rota-crds --sync-policy automated` makes the CRD follow Git, so it is
   always ahead of the instances that need it.
5. **Fault 4 - PostSync test.** `deploy/smoke-test.yaml` curls `http://shiftboard-api/`; the Service is
   `shiftboard`. Fix the host. Keep `curl` and keep it able to fail.
6. Commit, push, refresh `shiftboard`, sync it (`argocd app sync shiftboard`) and wait for Healthy. Verify:
   `kubectl -n shiftboard get cm schema-version -o yaml`, `kubectl -n shiftboard get shiftpolicy weekend -o yaml`,
   `argocd app get shiftboard` shows hooks `rota-migrate` and `shiftboard-smoke` Succeeded.

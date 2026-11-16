# Walkthrough — Migration Job Forbidden

1. **Read the failure.**
   ```bash
   argocd app get payroll-engine --show-operation      # PreSync hook ledger-migrate Failed
   kubectl -n payroll logs job/ledger-migrate          # 403: configmaps is forbidden ... cannot create resource
   kubectl -n payroll get role migrator -o yaml        # verbs: [get] only
   ```
2. **Notice that Git is right and the cluster is not.** `payroll-engine/deploy/rbac.yaml` grants `create`, but the
   Role is applied in the Sync phase. The sync never got there: PreSync hooks run first and the Job failed.
3. **Order the RBAC before the hook.** Make `Role` and `RoleBinding` PreSync hooks in an earlier wave than the Job:
   ```yaml
   metadata:
     name: migrator
     annotations:
       argocd.argoproj.io/hook: PreSync
       argocd.argoproj.io/sync-wave: "-1"
       argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
   ```
   (Alternative: keep RBAC as normal resources with `sync-wave: "-2"`, make the Job a `Sync` hook with wave `-1`.)
4. **Push and sync the new head.**
   ```bash
   git commit -am "migrator RBAC before the migration" && git push
   argocd app get payroll-engine --refresh
   argocd app sync payroll-engine
   ```
5. **Verify.** `kubectl -n payroll get configmap schema-version -o yaml` shows `version: v4.1`, the Application is
   Synced/Healthy and the Job shows as a PreSync hook that Succeeded.

# Walkthrough — Migrate Before You Deploy

1. **See what the sync would do.**
   ```bash
   argocd app get payroll-api     # OutOfSync: Deployment changed, Job missing
   argocd app diff payroll-api
   cat payroll-api/deploy/migrate-job.yaml
   ```
   The Job has no annotations: it is a normal resource of the `Sync` phase, wave 0. Argo CD applies the Job
   and the Deployment in the same `kubectl apply` round; the new ReplicaSet starts while the Job (12 s) runs.
2. **Order the migration first.** Add a hook annotation to the Job:
   ```yaml
   metadata:
     name: payroll-schema-migrate
     annotations:
       argocd.argoproj.io/hook: PreSync
   ```
   A `PreSync` hook runs before any other manifest of the sync is applied, and Argo CD waits until the hook
   is Healthy (the Job completed) before it moves on. If the Job fails, the sync stops and nothing is rolled out.
3. **Push and sync.**
   ```bash
   cd payroll-api && git commit -am "run the schema migration as a PreSync hook" && git push
   argocd app sync payroll-api --refresh   # or refresh first, then sync
   argocd app wait payroll-api --health
   ```
   `argocd app get payroll-api` now lists the Job with sync phase `PreSync` and hook phase `Succeeded`.
4. **Verify.**
   ```bash
   kubectl -n payroll get job,rs        # the Job completed before the new ReplicaSet was created
   kubectl -n payroll run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s payroll-api
   ```
   Then run `check` in the game.

Alternative: leave the Job a normal resource but give it a lower sync wave
(`argocd.argoproj.io/sync-wave: "-1"`). Argo CD finishes wave -1 (the Job must be Healthy = complete) before wave 0.

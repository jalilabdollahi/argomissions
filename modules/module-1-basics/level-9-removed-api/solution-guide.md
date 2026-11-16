# Walkthrough — Sync Failed: Unknown Kind

1. **Read the failure.**
   ```bash
   argocd app get billing
   ```
   The last operation is `Failed`, and the resource list shows the PodDisruptionBudget with
   `The Kubernetes API could not find version "v1beta1" of policy/PodDisruptionBudget ... Version "v1" of
   policy/PodDisruptionBudget is installed on the destination cluster.` Nothing else was applied: Argo CD
   validates every task before it creates anything.
2. **Check what the cluster serves.**
   ```bash
   kubectl api-versions | grep policy      # policy/v1 only
   kubectl api-resources | grep -i disruption
   ```
3. **Fix the manifest in Git.** In your workspace clone:
   ```bash
   cd billing
   sed -i 's#policy/v1beta1#policy/v1#' deploy/pdb.yaml
   git commit -am "pdb: policy/v1beta1 -> policy/v1" && git push
   ```
   The `spec` of a PodDisruptionBudget is identical in `v1`, so the rest of the file stays.
4. **Sync and watch.**
   ```bash
   argocd app sync billing
   argocd app wait billing --health
   ```
5. **Verify.**
   ```bash
   kubectl -n billing get deploy,svc,pdb
   kubectl -n billing run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s billing
   ```
   Then run `check` in the game.

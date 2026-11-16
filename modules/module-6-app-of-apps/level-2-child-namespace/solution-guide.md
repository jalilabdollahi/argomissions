# Walkthrough — Children In The Wrong Namespace

1. **Find the children.**
   ```bash
   argocd app list                                   # only billing-root
   argocd app get billing-root                       # Application invoice-api / dunning-worker, namespace billing-system
   kubectl get applications.argoproj.io -A           # they exist in billing-system, with empty SYNC/HEALTH
   ```
2. **Understand.** The manifests in `apps/` have no `metadata.namespace`, so Argo CD applies them into the root's
   destination namespace (`billing-system`). The application controller only watches `argocd`, so they are ignored.
3. **Fix the destination of the root.**
   ```bash
   argocd app set billing-root --dest-namespace argocd
   ```
   (Alternative: `namespace: argocd` in each child manifest in Git, push, refresh.)
   The children now appear in `argocd` and deploy their workloads.
4. **Remove the leftovers.** The root still tracks the two copies in `billing-system`; it shows `OutOfSync` with
   `requiresPruning`. Prune them:
   ```bash
   argocd app sync billing-root --prune
   ```
5. **Verify.**
   ```bash
   kubectl get applications.argoproj.io -A           # only namespace argocd
   argocd app list                                   # root and both children Synced / Healthy
   ```

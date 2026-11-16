# Walkthrough — Deleting The Child Left Everything

1. **Look at the leftovers.**
   ```bash
   argocd app list                                         # tariff-root, tariff-api only
   kubectl -n tariff-old get deploy,svc                    # tariff-legacy still runs
   kubectl -n tariff-old get deploy tariff-legacy -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'
   cd tariff-gitops && git log --stat -3                   # the retirement commit only deleted apps/legacy.yaml
   ```
2. **Understand.** An Application only deletes its resources when it is deleted with the finalizer
   `resources-finalizer.argocd.argoproj.io`. The children in Git had no `metadata.finalizers`, so the root's prune
   deleted just the Application object.
3. **Add the finalizer to every child in Git** (`apps/api.yaml`):
   ```yaml
   metadata:
     name: tariff-api
     namespace: argocd
     finalizers:
     - resources-finalizer.argocd.argoproj.io
   ```
4. **Clean up the orphan properly.** Restore `apps/legacy.yaml` (`git show HEAD~1:apps/legacy.yaml`), give it the
   finalizer too, push and let the root create and sync it. Then delete `apps/legacy.yaml` again and push: this time the
   deletion cascades and removes the Deployment and Service.
   (Shortcut: `kubectl delete namespace tariff-old` removes the leftovers by hand.)
5. **Verify.**
   ```bash
   argocd app list
   kubectl -n tariff-old get deploy,svc          # nothing
   kubectl -n argocd get application tariff-api -o jsonpath='{.metadata.finalizers}'
   ```

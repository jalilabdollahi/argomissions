# Walkthrough — Who Owns This?

1. **Ask Argo CD for the unowned objects.** The project has to opt in:
   ```bash
   argocd proj get search-platform        # no orphaned resources monitoring
   kubectl -n argocd patch appproject search-platform --type merge \
     -p '{"spec":{"orphanedResources":{"warn":true}}}'
   argocd app get query-service --hard-refresh     # (or wait for the next reconciliation)
   ```
   The Application now shows the condition `OrphanedResourceWarning  Application has 4 orphaned resources`.
2. **See what they are.**
   ```bash
   argocd app resources query-service --orphaned
   # Deployment legacy-indexer (+ its ReplicaSet and Pod), Secret search-tls-manual
   ```
3. **Decide per object.** The Deployment is a leftover load test: delete it
   (`kubectl -n search delete deployment legacy-indexer`; the ReplicaSet and Pod follow). The Secret is the
   documented exception: declare it on the project instead of deleting it:
   ```yaml
   spec:
     orphanedResources:
       warn: true
       ignore:
       - group: ""
         kind: Secret
         name: search-tls-manual
   ```
4. **Verify.** `argocd app get query-service --hard-refresh` shows no condition and
   `argocd app resources query-service --orphaned` lists nothing.

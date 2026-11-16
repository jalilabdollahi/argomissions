# Walkthrough — Annotation Too Long

1. **Read the failure.**
   ```bash
   argocd app get host-registry
   ```
   The ConfigMap is `OutOfSync` / `Missing` with `metadata.annotations: Too long: may not be more than 262144 bytes`;
   the Deployment and Service were created, but the pod cannot start because its ConfigMap volume is missing
   (`kubectl -n netops describe pod`).
2. **Measure the manifest.**
   ```bash
   wc -c host-registry/deploy/host-inventory.yaml     # ~415000 bytes
   ```
   The manifest has no annotation, so the oversized one is added by the apply itself: client-side apply writes the
   complete object into `kubectl.kubernetes.io/last-applied-configuration`.
3. **Do not shrink the data.** The objective needs all 9,000 hosts.
4. **Switch the application to server-side apply.**
   ```bash
   argocd app set host-registry --sync-option ServerSideApply=true
   argocd app sync host-registry
   argocd app wait host-registry --health
   ```
   (UI: App Details → Edit → Sync Options → *Server-Side Apply*. YAML: `spec.syncPolicy.syncOptions: [ServerSideApply=true]`.)
   Server-side apply tracks ownership in `managedFields` on the API server instead of an annotation.
5. **Verify.**
   ```bash
   kubectl -n netops get cm host-inventory -o json | jq '.data["hosts.txt"] | length'    # ~375000
   kubectl -n netops get cm host-inventory -o jsonpath='{.metadata.annotations}'          # no last-applied-configuration
   argocd app get host-registry
   ```
   Then run `check` in the game.

Variant: put `argocd.argoproj.io/sync-options: ServerSideApply=true` in the ConfigMap's metadata in Git and push;
only that resource then uses server-side apply.

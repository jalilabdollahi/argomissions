# Walkthrough — The Empty Root

1. **See that the root is healthy and empty.**
   ```bash
   argocd app list                      # only shopfront-root
   argocd app get shopfront-root        # Path: apps, Sync Status: Synced, no resources listed
   argocd app manifests shopfront-root  # nothing
   ```
2. **Compare with Git.**
   ```bash
   cd shopfront-fleet && git ls-files
   # apps/README.md, argocd/apps/cart.yaml, argocd/apps/catalog.yaml, workloads/...
   ```
   `apps/` holds only a README (not a manifest), the child Applications live in `argocd/apps/`.
3. **Point the root at the right folder.**
   ```bash
   argocd app set shopfront-root --path argocd/apps
   argocd app get shopfront-root --refresh
   ```
   Alternative: `git mv argocd/apps/*.yaml apps/`, commit and push; the root keeps its path.
4. **Verify.**
   ```bash
   argocd app list                      # shopfront-root, cart-svc, catalog-svc, all Synced / Healthy
   kubectl get application cart-svc -n argocd -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'
   ```
   The tracking id starts with `shopfront-root:`: the root owns its children.

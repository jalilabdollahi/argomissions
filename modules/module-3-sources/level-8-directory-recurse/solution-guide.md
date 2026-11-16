# Walkthrough — Half The Manifests

1. **Look at the Application.**
   ```bash
   argocd app get inventory        # Synced, Healthy, and no resources listed
   argocd app manifests inventory  # prints nothing
   kubectl get all -n inventory    # No resources found
   ```
2. **Look at the repo.**
   ```bash
   find inventory-stack/deploy -type f
   # deploy/web/deployment.yaml  deploy/web/service.yaml  deploy/db/deployment.yaml  deploy/db/service.yaml
   ```
   There is no manifest directly in `deploy/`; everything is one level deeper.
3. **Enable recursion.** A directory source reads only the top level of its path unless told otherwise:
   ```bash
   argocd app set inventory --directory-recurse
   ```
   (UI: App Details → Edit → *Directory Recurse* checkbox. YAML: `spec.source.directory.recurse: true`.)
4. **Sync and verify.**
   ```bash
   argocd app sync inventory
   argocd app wait inventory --health
   argocd app get inventory        # two Deployments and two Services
   ```
   Then run `check` in the game.

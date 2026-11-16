# Walkthrough - The Base Is Not An Environment

1. **Compare the renders locally.**
   ```bash
   kubectl kustomize inventory-sync/kustomize/base            | grep -E "replicas|text"   # 1, base
   kubectl kustomize inventory-sync/kustomize/overlays/prod   | grep -E "replicas|text"   # 3, prod
   ```
2. **See what the Application uses.**
   ```bash
   argocd app get inventory-sync     # Path: kustomize/base
   ```
3. **Change the path to the production overlay and sync.**
   ```bash
   argocd app set inventory-sync --path kustomize/overlays/prod
   argocd app sync inventory-sync
   argocd app wait inventory-sync --health
   ```
   (UI: App Details, Edit, Path.)
4. **Verify.**
   ```bash
   kubectl -n inventory get deploy inventory-sync     # 3/3
   kubectl -n inventory run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s inventory-sync
   ```
   Then run `check` in the game.

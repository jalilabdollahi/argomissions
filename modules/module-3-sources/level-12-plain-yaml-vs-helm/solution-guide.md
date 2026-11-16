# Walkthrough — Detected As The Wrong Tool

1. **What does Argo CD think this is?**
   ```bash
   argocd app get docs-portal
   argocd app manifests docs-portal      # nothing
   kubectl -n docs get all               # nothing
   ```
   In the UI, the Application details show the tool as Helm.
2. **Look at the folder.**
   ```bash
   ls docs-portal/deploy
   # Chart.yaml  deployment.yaml  service.yaml  values.yaml
   ```
   A `Chart.yaml` was left behind by an abandoned Helm experiment.
3. **Remove the stray files** and push:
   ```bash
   cd docs-portal
   git rm deploy/Chart.yaml deploy/values.yaml
   git commit -m "remove leftover Helm files" && git push
   ```
   (Alternative: `argocd app set docs-portal --directory-recurse` forces the Directory type without touching Git.)
4. **Verify.**
   ```bash
   argocd app get docs-portal --refresh      # Deployment and Service appear, automated sync deploys them
   argocd app wait docs-portal --health
   kubectl -n docs get deploy,svc,pods
   ```
   Then run `check` in the game.

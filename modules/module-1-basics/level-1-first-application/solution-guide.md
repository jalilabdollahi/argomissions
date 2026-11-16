# Walkthrough — Hello, GitOps

1. **See what Argo CD knows.**
   ```bash
   argocd app list            # empty: no Application exists
   ls status-page/deploy      # deployment.yaml, service.yaml
   ```
2. **Create the Application.** Argo CD runs in the cluster, so it reads Gitea through the Service DNS name,
   not through `localhost:3300`:
   ```bash
   argocd app create status-page \
     --repo http://gitea.gitea.svc.cluster.local:3000/platform/status-page.git \
     --path deploy --revision main \
     --dest-server https://kubernetes.default.svc --dest-namespace status
   ```
   (UI: **+ New App** → name `status-page`, project `default`, the repo URL above, path `deploy`,
   cluster `https://kubernetes.default.svc`, namespace `status`.)
3. **Look at it.** `argocd app get status-page` shows `Sync Status: OutOfSync` and `Health Status: Missing`:
   Argo CD compared Git with the cluster and found two objects missing. With a manual sync policy it waits.
4. **Sync.**
   ```bash
   argocd app sync status-page
   argocd app wait status-page --health
   ```
5. **Verify.**
   ```bash
   argocd app get status-page          # Synced, Healthy
   kubectl -n status get deploy,svc,pods
   kubectl -n status run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s status-page
   ```
   Then run `check` in the game.

The same Application as YAML (what most teams keep in Git):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: status-page
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea.gitea.svc.cluster.local:3000/platform/status-page.git
    targetRevision: main
    path: deploy
  destination:
    server: https://kubernetes.default.svc
    namespace: status
```

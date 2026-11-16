# Walkthrough — One Secret For The Org

1. **See the problem.**
   ```bash
   argocd app list                    # five apps, all Unknown
   argocd app get kiosk-menu          # ... authentication required: Unauthorized
   argocd repo list; argocd repocreds list     # both empty
   ```
2. **Add one credential template** for the whole organisation URL:
   ```bash
   argocd repocreds add http://gitea.gitea.svc.cluster.local:3000/platform \
     --username argo-reader --password reader-pass-1Wm6
   ```
   Declarative equivalent:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: creds-platform-org
     namespace: argocd
     labels:
       argocd.argoproj.io/secret-type: repo-creds
   stringData:
     type: git
     url: http://gitea.gitea.svc.cluster.local:3000/platform
     username: argo-reader
     password: reader-pass-1Wm6
   ```
3. **Refresh** every app (`argocd app get NAME --hard-refresh`); the automated sync deploys each one.
4. **Verify**: all five apps Synced/Healthy; `argocd repocreds list` shows a single entry. Registering five
   repositories separately would work, but is exactly what the template removes.
